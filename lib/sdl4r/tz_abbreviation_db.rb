#!/usr/bin/env ruby -w
# encoding: UTF-8

#--
#
# Simple Declarative Language (SDL) for Ruby
# Copyright 2005 Ikayzo, inc.
#
# This program is free software. You can distribute or modify it under the
# terms of the GNU Lesser General Public License version 2.1 as published by
# the Free Software Foundation.
#
# This program is distributed AS IS and WITHOUT WARRANTY. OF ANY KIND,
# INCLUDING MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program; if not, contact the Free Software Foundation, Inc.,
# 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
#++

module SDL4R

  require 'csv'
  require 'thread'

  if __FILE__ == $PROGRAM_NAME
    require 'rubygems'
    require 'tzinfo'
    require 'ostruct'
  end

  require 'sdl4r/constant_timezone'

  # Gathers an index database of time zone abbreviations (e.g. "PST", "JST").
  #
  # For each abbreviation, there are 3 basic cases:
  # - no ambiguity: the abbreviation is always used with the same offsets (even if in different
  #  countries).
  # - time ambiguity: the abbreviation has been used in the same places but with different offsets
  #  at different times. In this case, we base the timezone on one of the geographical time zones.
  # - modern time ambiguity: the abbreviation has been used in different places but only before
  #  1970. It's been stable since. As it is the case of widely used abbreviations like "CET", a
  #  modernly-used geographical timezone should be used as for the "time ambiguity" case, at least
  #  by default.
  # - location ambiguity: the abbreviation has been used in different places. In this case, there
  #  is no way to tell, which place is the right one and therefore an error should be raised.
  #
  # Note that 'utc_offset' and 'std_offset' of Record are meaningful only if the abbreviation is
  # not ambiguous.
  #
  class TZAbbreviationDB # :nodoc:

    class Record

      attr_reader :identifier, :utc_offset, :std_offset, :use
      attr_accessor :linked_zone_ids

      # :not_ambiguous
      # :time_ambiguous
      # :modern_time_ambiguous
      # :too_ambiguous
      #
      attr_accessor :annotation

      def initialize(identifier, utc_offset, std_offset, annotation, use, linked_zone_ids)
        @identifier = identifier
        @utc_offset = utc_offset
        @std_offset = std_offset
        @annotation = annotation
        @use = use
        @linked_zone_ids = linked_zone_ids
      end

    end

    DB_FILENAME = File.dirname(__FILE__) + "/tz_abbreviation_db.csv"

    @@index = nil
    @@index_mutex = Mutex.new
    

    def self.get_timezone(identifier, consider_modern_abbreviations = true)
      tz = nil

      begin
        tz = TZInfo::Timezone.get(identifier)
        
      rescue TZInfo::InvalidTimezoneIdentifier => error1
        # check whether we can find an abbreviation
        abbreviation = TZAbbreviationDB.get_record(identifier)
        if abbreviation
          if abbreviation.annotation == :not_ambiguous
            tz = ConstantTimezone.new(
              abbreviation.identifier, abbreviation.utc_offset, abbreviation.std_offset)

          elsif abbreviation.annotation == :time_ambiguous or
              (abbreviation.annotation == :modern_time_ambiguous and consider_modern_abbreviations)
            begin
              base_tz = TZInfo::Timezone.get(abbreviation.linked_zone_ids[0])
              tz = RelativeTimezone.new(abbreviation.identifier, "", 0, base_tz)
            rescue TZInfo::InvalidTimezoneIdentifier
              tz = nil
            end
          end
        end

        raise error1 if tz.nil?
      end

      tz
    end

    def self.get_timezone_proxy(identifier, consider_modern_abbreviations = true)
      return AbbreviationTimezoneProxy.new(identifier, consider_modern_abbreviations)
    end

    # Returns the Record corresponding to the specified identifier or nil if not found.
    # Be sure to check the 'annotation' property before using the data of the record.
    #
    def self.get_record(identifier)
      @@index_mutex.synchronize do
        load_file unless @@index
      end
      return @@index[identifier]
    end

    # Loads the CSV file (#DB_FILENAME) into memory.
    #
    def self.load_file
      index = {}
      CSV.foreach(DB_FILENAME) do |row|
        record = Record.new(
          row[0], row[1].to_i, row[2].to_i, row[3].to_sym, row[4].to_sym, row[5..-1].sort!)
        index[record.identifier] = record
      end
      @@index = index
    end

    def self.clean_raw_record_index(raw_index)
      index = {}

      # Clean up and annotate the ambiguous cases
      raw_index.each_pair { |identifier, records|
        if records.length == 1
          record = records[0]
          record.annotation = :not_ambiguous

        else
          # check whether locations differ
          record = create_ambiguous_record(records, nil, :time_ambiguous)
          if record.annotation == :too_ambiguous
            salvaged_record = create_ambiguous_record(records, :modern, :modern_time_ambiguous)
            record = salvaged_record if salvaged_record
          end
        end

        index[record.identifier] = record
      }
      
      return index
    end

    # Check the locations of the records and create a corresonding record annotated as ambiguous
    # according to its level: either 'default_annotation' or :too_ambiguous if the locations where
    # the abbreviation is used differ along time (for the given 'use').
    #
    #  _use_:: indicates the only kind of use considered or nil for all of them
    # _default_annotation_:: annotation to set if locations do not differ
    #
    def self.create_ambiguous_record(records, use, default_annotation)
      records = records.reject { |item| item.use != use } if use
      return nil if records.empty?

      record = records[0]
      record.annotation = default_annotation

      locations = nil
      records.each { |item|
        if locations
          record.annotation = :too_ambiguous if locations != item.linked_zone_ids
        else
          locations = item.linked_zone_ids
        end
      }

      linked_zone_ids = {}
      records.each { |item|
        item.linked_zone_ids.each { |loc|
          linked_zone_ids[loc] = nil
        }
      }
      record.linked_zone_ids = linked_zone_ids.keys.sort

      return record
    end

    # Creates a CSV index file of abbreviations and their corresponding offsets and unambiguous
    # corresponding zones.
    #
    # This method relies on unpublished internals of TZInfo. Therefore, it might easily break in
    # the future.
    #
    def self.generate_file
      abbreviation_index = {}

      TZInfo::Timezone.all_data_zone_identifiers.each { |tz_id|
        tz = TZInfo::Timezone.get(tz_id)
        info = tz.instance_variable_get(:@info)
        offsets = info.instance_variable_get(:@offsets)
        transitions = info.instance_variable_get(:@transitions)

        if offsets
          offsets.each_value { |offset|
            if tz.identifier != offset.abbreviation.id2name
              offset_key = [offset.abbreviation.id2name, offset.utc_offset, offset.std_offset]

              abbreviation_index[offset_key] ||= OpenStruct.new(:timezones => [], :use => :historical)
              offset_record = abbreviation_index[offset_key]

              unless offset_record.timezones.include? tz.identifier
                offset_record.timezones << tz.identifier
              end

              # Find the last use of that offset
              previous_transition = nil
              (transitions.length - 1).downto(0) { |i|
                transition = transitions[i]
                if offset == transition.offset
                  if previous_transition.nil? or previous_transition.at.year >= 1970
                    offset_record.use = :modern
                  end
                  break
                end
                previous_transition = transition
              }
            end
          }
        end
      }

      # Create a raw index of Records keyed by identifiers
      raw_record_index = {}
      abbreviation_index.each_pair { |offset, item|
        record = Record.new(offset[0], offset[1], offset[2], nil, item.use, item.timezones)
        raw_record_index[record.identifier] ||= []
        raw_record_index[record.identifier] << record
      }

      record_index = clean_raw_record_index(raw_record_index)

      sorted = record_index.sort { |a, b| a[0] <=> b[0] }
      CSV::open(DB_FILENAME, "w") do |writer|
        sorted.each { |offset, record|
          writer << [
            record.identifier, record.utc_offset, record.std_offset, record.annotation, record.use] +
            record.linked_zone_ids
        }
      end
    end
  end

  if __FILE__ == $PROGRAM_NAME
    TZAbbreviationDB.generate_file
  end
end

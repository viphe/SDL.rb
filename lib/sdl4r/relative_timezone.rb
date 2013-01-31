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

  require 'sdl4r/tz_abbreviation_db'

  # Represents a Timezone which is distant from a standard timezone by a fixed offset.
  #
  class RelativeTimezone < TZInfo::Timezone

    # Returns a timezone by its identifier (e.g. "Europe/London",
    # "America/Chicago" or "UTC").
    #
    # Supports relative timezones in the following formats: "UTC+2", "GMT+01:30",
    # "Europe/Paris-10:00".
    #
    # Raises InvalidTimezoneIdentifier if the timezone couldn't be found.
    #
    def self.get(identifier)
      base_identifier, offset_text, offset = RelativeTimezone::parse_relative_identifier(identifier)

      tz = TZAbbreviationDB.get_timezone(base_identifier)

      offset ?
        RelativeTimezone.new(base_identifier + offset_text.to_s, offset_text, offset, tz) :
        tz
    end

    # Returns a proxy for the Timezone with the given identifier. The proxy
    # will cause the real timezone to be loaded when an attempt is made to
    # find a period or convert a time. get_proxy will not validate the
    # identifier. If an invalid identifier is specified, no exception will be
    # raised until the proxy is used.
    #
    # Supports relative timezones in the following format: "GMT+01:30", "CET-10:00".
    #
    def self.get_proxy(identifier)
      base_identifier, offset_text, offset = RelativeTimezone::parse_relative_identifier(identifier)

      proxy = TZAbbreviationDB.get_timezone_proxy(base_identifier)

      offset ?
        RelativeTimezone.new(base_identifier + offset_text.to_s, offset_text, offset, proxy) :
        proxy
    end

    # Parses the specified identifier of the shape "GMT" or "CET+7" or "Asia/Shanghai-03:30" and
    # returns an array containing respectively the simple zone identifier (e.g. "CET",
    # "Asia/Shanghai"), the offset part (e.g. "-6", "+08:30") and the offset (seconds).
    #
    def self.parse_relative_identifier(identifier) # :nodoc:
      offset = nil

      if identifier =~ /^([a-zA-Z0-9\/_]+)(([+\-])(\d+)(?::(\d+))?)?$/
        identifier, offset_text, sign_part, hour_part, minute_part = $1, $2, $3, $4, $5

        if sign_part # relative offset
          offset = 0
          offset += 3600 * hour_part.to_i if hour_part
          offset += 60 * minute_part.to_i if minute_part
          offset = -offset if sign_part == '-'

          offset = nil if offset == 0

          # We regenerate/normalize the offset text "+7:3" ==> "+07:03".
          offset_text = ""
          if offset
            offset_text << (offset >= 0 ? '+' : '-')

            hours = offset.abs / 3600
            minutes = (offset.abs % 3600) / 60
            if minutes == 0
              offset_text << hours.to_s
            else
              offset_text << sprintf("%02d:%02d", hours, minutes)
            end
          end
        end
      end

      return identifier, offset_text, offset
    end

    def self.new(identifier, offset_text, offset, base_timezone)
      o = super()
      o.send(:_initialize, identifier, offset_text, offset, base_timezone)
      o
    end
    
    # _base_timezone_:: timezone on which this RelativeTimezone is based
    # _offset_:: the fixed offset (seconds)
    #
    def _initialize(identifier, offset_text, offset, base_timezone) # :nodoc:
      raise ArgumentError, 'identifier' if identifier.nil?
      raise ArgumentError, 'offset' if offset.nil?
      raise ArgumentError, 'base_timezone' if base_timezone.nil?

      @identifier = identifier
      @base_timezone =
        base_timezone.is_a?(String) ? TZInfo::Timezone.get(base_timezone) : base_timezone
      @relative_offset_text = offset_text
      @relative_offset = offset
    end
    protected :_initialize
    
    attr_reader :identifier, :relative_offset

    def period_for_utc(utc)
      period = @base_timezone.period_for_utc(utc)

      translated_offset =
        period.offset ?
          TZInfo::TimezoneOffsetInfo.new(
            period.offset.utc_offset + @relative_offset,
            period.offset.std_offset,
            (period.offset.abbreviation.to_s + @relative_offset_text).to_sym) :
          nil

      return TZInfo::TimezonePeriod.new(nil, nil, translated_offset)
    end

    def periods_for_local(local)
      periods = @base_timezone.periods_for_local(local)

      return periods.collect { |period|
        translated_offset =
          period.offset ?
            TZInfo::TimezoneOffsetInfo.new(
              period.offset.utc_offset + @relative_offset,
              period.offset.std_offset,
              (period.offset.abbreviation.to_s + @relative_offset_text).to_sym) :
            nil
        TZInfo::TimezonePeriod.new(nil, nil, translated_offset)
      }
    end
  end
end
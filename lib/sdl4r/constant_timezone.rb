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

  # A timezone like 'JST' that has only one definition whatever the place and the time.
  #
  class ConstantTimezone < TZInfo::Timezone

    def self.new(identifier, utc_offset, std_offset)
      o = super()
      o.send(:_initialize, identifier, utc_offset, std_offset)
      o
    end

    def _initialize(identifier, utc_offset, std_offset) # :nodoc:
      raise ArgumentError, 'identifier' if identifier.nil?
      raise ArgumentError, 'utc_offset' if utc_offset.nil?
      raise ArgumentError, 'std_offset' if std_offset.nil?

      @identifier = identifier
      @utc_offset = utc_offset
      @std_offset = std_offset
      @period = TZInfo::TimezonePeriod.new(
        nil, nil, TZInfo::TimezoneOffsetInfo.new(@utc_offset, @std_offset, @identifier.to_sym))
    end

    def identifier
      @identifier
    end

    def period_for_utc(utc)
      @period
    end

    def periods_for_local(local)
      [@period]
    end
  end
end

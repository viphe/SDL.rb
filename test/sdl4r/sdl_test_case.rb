#!/usr/bin/env ruby -w
# encoding: UTF-8

#--
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

  require 'test/unit'
  
  module SdlTestCase

    def assert_equal_date_time(expected, actual, message = nil)
      begin
        assert_equal expected, actual
      rescue Test::Unit::AssertionFailedError
        first_error = $!
        begin
          if expected.class == actual.class
            if expected.is_a? DateTime
              assert_equal expected.strftime("%F %T.%L %z"), actual.strftime("%F %T.%L %z"), message
            elsif expected.is_a? Time
              assert_equal expected.xmlschema(3), actual.xmlschema(3), message
            else
              assert_equal expected, actual, message
            end
          else
            assert_equal expected, actual, message
          end
          raise first_error
        rescue
          raise $!
        end
      end
    end

    # Creates and returns a DateTime where an unspecified +zone_offset+ means 'the local zone
    # offset' (contrarily to DateTime#civil())
    def local_civil_date(year, month, day, hour = 0, min = 0, sec = 0, zone_offset = nil)
      sec = Rational((sec * 1000).to_i, 1000) if sec.is_a? Float
      @@current_zone_offset ||= Rational(Time.now.utc_offset,  24 * 60 * 60)
      zone_offset ||= @@current_zone_offset
      return DateTime.civil(year, month, day, hour, min, sec, zone_offset)
    end
  end
end
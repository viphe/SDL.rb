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

  require 'test/unit'

  TZINFO_AVAILABLE = begin
    require 'tzinfo'
    require 'sdl4r/relative_timezone'
    true
  rescue LoadError
    false
  end unless defined? TZINFO_AVAILABLE

  require "sdl4r/sdl_test_case"

  class RelativeTimezoneTest < Test::Unit::TestCase
    include SdlTestCase

    def test_skipped_because_no_tzinfo
    end unless TZINFO_AVAILABLE

    def test_get
      TZInfo::Timezone.get("GMT")
      tz = SDL4R::RelativeTimezone.get("GMT")

      assert_equal "GMT", tz.identifier
      assert !tz.is_a?(SDL4R::RelativeTimezone)

      tz = SDL4R::RelativeTimezone.get("GMT+01:30")
      assert_equal "GMT+01:30", tz.identifier
      assert_kind_of SDL4R::RelativeTimezone, tz
      assert_equal 5400, tz.relative_offset

      tz_period = tz.period_for_utc(Time.utc(2001, 1, 25, 21, 45, 50, 123))
      assert_equal 5400, tz_period.utc_offset
      assert_equal 0, tz_period.std_offset
      assert_equal :"GMT+01:30", tz_period.abbreviation

      tz = SDL4R::RelativeTimezone.get("CET-02:00")
      assert_equal "CET-2", tz.identifier
      assert_kind_of SDL4R::RelativeTimezone, tz
      assert_equal(-7200, tz.relative_offset)

      tz_period = tz.period_for_utc(Time.utc(2001, 1, 25, 21, 45, 50, 123))
      assert_equal 3600 - 7200, tz_period.utc_offset
      assert_equal 0, tz_period.std_offset
      assert_equal :"CET-2", tz_period.abbreviation

      tz = SDL4R::RelativeTimezone.get("Europe/Paris+01:40")
      assert_equal "Europe/Paris+01:40", tz.identifier
      assert_kind_of SDL4R::RelativeTimezone, tz
      assert_equal 6000, tz.relative_offset

      tz_period = tz.period_for_local(Time.utc(2001, 1, 1, 21, 45, 50, 123))
      assert_equal 3600 + 6000, tz_period.utc_offset
      assert_equal 3600 + 6000, tz_period.utc_total_offset
      assert_equal 0, tz_period.std_offset
      assert_equal :"CET+01:40", tz_period.abbreviation

      tz_period = tz.period_for_local(Time.utc(2001, 7, 1, 21, 45, 50, 123))
      assert_equal 3600 + 6000, tz_period.utc_offset
      assert_equal 7200 + 6000, tz_period.utc_total_offset
      assert_equal 3600, tz_period.std_offset
      assert_equal :"CEST+01:40", tz_period.abbreviation

      tz = SDL4R::RelativeTimezone.get("GMT+7")
      assert_equal "GMT+7", tz.identifier

      tz = SDL4R::RelativeTimezone.get("GMT-07")
      assert_equal "GMT-7", tz.identifier

      tz = SDL4R::RelativeTimezone.get("GMT+7:32")
      assert_equal "GMT+07:32", tz.identifier

      tz = SDL4R::RelativeTimezone.get("GMT-7:32")
      assert_equal "GMT-07:32", tz.identifier

      # Test abbreviations
      tz = SDL4R::RelativeTimezone.get("JST")
      assert_equal "JST", tz.identifier

      tz = SDL4R::RelativeTimezone.get("JST+8")
      assert_equal "JST+8", tz.identifier

      assert_raise TZInfo::InvalidTimezoneIdentifier do
        SDL4R::RelativeTimezone.get("LMT")
      end
    end if TZINFO_AVAILABLE
  end
end
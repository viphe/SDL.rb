#!/usr/bin/env ruby -w
# encoding: UTF-8

#--
#
# Simple Declarative Language (SDL) for Ruby
# Copyright 2013 Ikayzo, inc.
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

if RUBY_VERSION < '1.9.0'
  $KCODE = 'u'
  require 'jcode'
end

module SDL4R

  require 'fileutils'
  require 'pathname'
  require 'date'
  require 'test/unit'


  require 'sdl4r/sdl4r'
  require 'sdl4r/sdl4r_date'

  require 'sdl4r/test_helper'

  class SDL4RDateTest < Test::Unit::TestCase
    include TestHelper

    def test_years
      assert_equal_date_time(
        local_civil_date(2010, 01, 01, 1, 11, 11.111),
        SDL4R::new_exotic_date_time(2010, 01, 01, 1, 11, 11, 111))
      assert_equal_date_time(
        local_civil_date(1, 01, 01, 1, 11, 11.111),
        SDL4R::new_exotic_date_time(1, 01, 01, 1, 11, 11, 111))

      # somehow DateTime seems to support a year 0 that never happened...
      #assert_equal_date_time(
      #  local_civil_date(0, 01, 01, 1, 11, 11.111),
      #  SDL4R::new_exotic_date_time(1, 01, 01, 1, 11, 11, 111))

      assert_equal_date_time(
        local_civil_date(-1, 01, 01, 1, 11, 11.111),
        SDL4R::new_exotic_date_time(-1, 01, 01, 1, 11, 11, 111))
    end

    def test_months
      # checking everything is fine in December
      assert_equal_date_time(
        local_civil_date(2010, 12, 01, 1, 11, 11.111),
        SDL4R::new_exotic_date_time(2010, 12, 01, 1, 11, 11, 111))

      assert_equal_date_time(
        local_civil_date(2011, 01, 01, 01, 11, 11.111),
        SDL4R::new_exotic_date_time(2010, 13, 01, 01, 11, 11, 111))
      assert_equal_date_time(
        local_civil_date(2010, 01, 01, 01, 11, 11.111),
        SDL4R::new_exotic_date_time(2010, 00, 01, 01, 11, 11, 111))
      assert_equal_date_time(
        local_civil_date(2009, 12, 01, 01, 11, 11.111),
        SDL4R::new_exotic_date_time(2010, -1, 01, 01, 11, 11, 111))
      assert_equal_date_time(
        local_civil_date(2009, 01, 01, 01, 11, 11.111),
        SDL4R::new_exotic_date_time(2010, -12, 01, 01, 11, 11, 111))
      assert_equal_date_time(
        local_civil_date(2008, 01, 01, 01, 11, 11.111),
        SDL4R::new_exotic_date_time(2010, -24, 01, 01, 11, 11, 111))
    end

    def test_days
      # 2010 is not a leap year, 2012 is
      assert_equal_date_time(
        local_civil_date(2010, 01, 31, 1, 11, 11.111),
        SDL4R::new_exotic_date_time(2010, 01, 31, 1, 11, 11, 111))
      assert_equal_date_time(
        local_civil_date(2010, 02, 28, 1, 11, 11.111),
        SDL4R::new_exotic_date_time(2010, 02, 28, 1, 11, 11, 111))
      assert_equal_date_time(
        local_civil_date(2012, 02, 29, 1, 11, 11.111),
        SDL4R::new_exotic_date_time(2012, 02, 29, 1, 11, 11, 111))

      assert_equal_date_time(
        local_civil_date(2010, 02, 01, 1, 11, 11.111),
        SDL4R::new_exotic_date_time(2010, 01, 32, 1, 11, 11, 111))
      assert_equal_date_time(
        local_civil_date(2010, 03, 01, 1, 11, 11.111),
        SDL4R::new_exotic_date_time(2010, 02, 29, 1, 11, 11, 111))
      assert_equal_date_time(
        local_civil_date(2012, 03, 01, 1, 11, 11.111),
        SDL4R::new_exotic_date_time(2012, 02, 30, 1, 11, 11, 111))
      assert_equal_date_time(
        local_civil_date(2012, 03, 01, 1, 11, 11.111),
        SDL4R::new_exotic_date_time(2012, 01, 61, 1, 11, 11, 111))

      assert_equal_date_time(
        local_civil_date(2009, 12, 31, 1, 11, 11.111),
        SDL4R::new_exotic_date_time(2010, 01, -1, 1, 11, 11, 111))
      assert_equal_date_time(
        local_civil_date(2009, 11, 30, 1, 11, 11.111),
        SDL4R::new_exotic_date_time(2010, 01, -32, 1, 11, 11, 111))
      assert_equal_date_time(
        local_civil_date(2009, 01, 01, 1, 11, 11.111),
        SDL4R::new_exotic_date_time(2010, 01, -365, 1, 11, 11, 111))
    end

    def test_hours
      assert_equal_date_time(
        local_civil_date(2010, 01, 01, 00, 11, 11.111),
        SDL4R::new_exotic_date_time(2010, 01, 01, 00, 11, 11, 111))
      assert_equal_date_time(
        local_civil_date(2010, 01, 01, 23, 11, 11.111),
        SDL4R::new_exotic_date_time(2010, 01, 01, 23, 11, 11, 111))

      assert_equal_date_time(
        local_civil_date(2010, 02, 01, 00, 11, 11.111),
        SDL4R::new_exotic_date_time(2010, 01, 31, 24, 11, 11, 111))
      assert_equal_date_time(
        local_civil_date(2010, 02, 01, 01, 11, 11.111),
        SDL4R::new_exotic_date_time(2010, 01, 31, 25, 11, 11, 111))
      assert_equal_date_time(
        local_civil_date(2010, 02, 02, 00, 11, 11.111),
        SDL4R::new_exotic_date_time(2010, 01, 31, 48, 11, 11, 111))

      assert_equal_date_time(
        local_civil_date(2009, 12, 31, 23, 11, 11.111),
        SDL4R::new_exotic_date_time(2010, 01, 01, -1, 11, 11, 111))
      assert_equal_date_time(
        local_civil_date(2009, 12, 31, 00, 11, 11.111),
        SDL4R::new_exotic_date_time(2010, 01, 01, -24, 11, 11, 111))
      assert_equal_date_time(
        local_civil_date(2009, 12, 30, 23, 11, 11.111),
        SDL4R::new_exotic_date_time(2010, 01, 01, -25, 11, 11, 111))
    end

    def test_minutes
      assert_equal_date_time(
        local_civil_date(2010, 01, 01, 01, 59, 11.111),
        SDL4R::new_exotic_date_time(2010, 01, 01, 01, 59, 11, 111))
      assert_equal_date_time(
        local_civil_date(2010, 01, 01, 01, 00, 11.111),
        SDL4R::new_exotic_date_time(2010, 01, 01, 01, 00, 11, 111))

      assert_equal_date_time(
        local_civil_date(2010, 01, 01, 02, 00, 11.111),
        SDL4R::new_exotic_date_time(2010, 01, 01, 01, 60, 11, 111))
      assert_equal_date_time(
        local_civil_date(2010, 01, 01, 00, 59, 11.111),
        SDL4R::new_exotic_date_time(2010, 01, 01, 01, -1, 11, 111))
      assert_equal_date_time(
        local_civil_date(2009, 12, 31, 23, 59, 11.111),
        SDL4R::new_exotic_date_time(2010, 01, 01, 01, -61, 11, 111))
    end

    def test_seconds
      assert_equal_date_time(
        local_civil_date(2010, 01, 01, 01, 01, 0.111),
        SDL4R::new_exotic_date_time(2010, 01, 01, 01, 01, 00, 111))
      assert_equal_date_time(
        local_civil_date(2010, 01, 01, 01, 01, 59.111),
        SDL4R::new_exotic_date_time(2010, 01, 01, 01, 01, 59, 111))

      assert_equal_date_time(
        local_civil_date(2010, 01, 01, 01, 02, 0.111),
        SDL4R::new_exotic_date_time(2010, 01, 01, 01, 01, 60, 111))
      assert_equal_date_time(
        local_civil_date(2010, 01, 01, 01, 00, 59.111),
        SDL4R::new_exotic_date_time(2010, 01, 01, 01, 01, -1, 111))
      assert_equal_date_time(
        local_civil_date(2010, 01, 01, 00, 59, 59.111),
        SDL4R::new_exotic_date_time(2010, 01, 01, 01, 01, -61, 111))
    end

    def test_milliseconds
      assert_equal_date_time(
        local_civil_date(2010, 01, 01, 01, 01, 0.999),
        SDL4R::new_exotic_date_time(2010, 01, 01, 01, 01, 01, -1))
    end
  end

end
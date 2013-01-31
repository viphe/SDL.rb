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

# Work-around a bug in NetBeans (http://netbeans.org/bugzilla/show_bug.cgi?id=188653)
if ENV["NB_EXEC_EXTEXECUTION_PROCESS_UUID"]
  $:[0] = File.join(File.dirname(__FILE__),'../../lib')
  $:.unshift(File.join(File.dirname(__FILE__),'../../test'))
end

if RUBY_VERSION < '1.9.0'
  $KCODE = 'u'
  require 'jcode'
end

module SDL4R

  require 'fileutils'
  require 'pathname'
  require 'date'
  require 'test/unit'

  require 'sdl4r'
  # We don't do
  #
  #   require 'sdl4r_tzinfo'
  #
  # as we only want to enable TZInfo on a per test basis.
  begin
    require 'tzinfo'
    TZINFO_AVAILABLE = true
  rescue LoadError
    TZINFO_AVAILABLE = false
  end
  require 'sdl4r/sdl4r_tzinfo' if TZINFO_AVAILABLE

  require 'sdl4r/sdl_test_case'

  class Sdl4rTZInfoTest < Test::Unit::TestCase
    include SdlTestCase

    def test_skipped_because_no_tzinfo
    end unless TZINFO_AVAILABLE

    def setup
      super
      SDL4R::enable_tzinfo
    end if TZINFO_AVAILABLE

    def teardown
      begin
        SDL4R::disable_tzinfo
      rescue
        super
      end
    end if TZINFO_AVAILABLE

    def test_datetime
      # no timezone
      root = SDL4R::read("tag1 1998/05/12 12:34:56.768")
      assert_kind_of DateTime, root.child.value
      assert_equal_date_time local_civil_date(1998, 05, 12, 12, 34, 56.768), root.child.value

      root = SDL4R::read("tag1 1998/05/12 12:34:56.768-UTC")
      assert_equal_date_time local_civil_date(1998, 05, 12, 12, 34, 56.768, "UTC"), root.child.value

      root = SDL4R::read("tag1 1998/05/12 12:34:56.768-JST")
      assert_equal_date_time local_civil_date(1998, 05, 12, 12, 34, 56.768, "JST"), root.child.value

      root = SDL4R::read("tag1 1998/05/12 12:34:56.768-GMT-01:00")
      assert_equal_date_time local_civil_date(1998, 05, 12, 12, 34, 56.768, "GMT-01:00"), root.child.value
    end if TZINFO_AVAILABLE

    # Date parsing tests using Time rather than DateTime
    def test_time
      SDL4R::use_datetime = false
      begin
         # no timezone
        root = SDL4R::read("tag1 1998/05/12 12:34:56.768")
        assert_kind_of Time, root.child.value
        assert_equal_date_time Time.local(1998, 05, 12, 12, 34, 56, 768000), root.child.value

        root = SDL4R::read("tag1 1998/05/12 12:34:56.768-UTC")
        assert_equal_date_time Time.utc(1998, 05, 12, 12, 34, 56, 768000), root.child.value

        root = SDL4R::read("tag1 1998/05/12 12:34:56.768-JST")
        assert_equal_date_time Time.xmlschema("1998-05-12T12:34:56.768+09:00"), root.child.value

        root = SDL4R::read("tag1 1998/05/12 12:34:56.768-GMT-01:00")
        assert_equal_date_time Time.xmlschema("1998-05-12T12:34:56.768-01:00"), root.child.value

        root = SDL4R::read("tag1 1998/05/12 12:34:56.768-JST-01:30")
        assert_equal_date_time Time.xmlschema("1998-05-12T12:34:56.768+07:30"), root.child.value

      ensure
        SDL4R::use_datetime = true
      end
    end if TZINFO_AVAILABLE
  end
end

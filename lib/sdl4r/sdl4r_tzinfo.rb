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

require 'date'

require 'sdl4r/sdl4r'
require 'sdl4r/relative_timezone'

# Modification of SDL4R in order to use TZInfo for parsing time zones.
#
class << SDL4R

  alias_method :tzinfo_orig_new_time, :new_time

  # Creates and returns the object representing a time (DateTime by default).
  # This method is called by the Parser class.
  #
  # This implementation uses TZInfo in order to parse timezones (wider support of timezones and
  # better support of DST and such issues).
  #
  # See #use_datetime=
  #
  def tzinfo_replac_new_time(year, month, day, hour, min, sec, msec, timezone_code)
    if timezone_code
      timezone = SDL4R::RelativeTimezone::get(timezone_code)
      tz_ref_time = Time.utc(year, month, day, hour, min, sec, msec * 1000)
      # Arbitrary decision: in ambiguous cases, we choose the not-DST offset.
      timezone_period = timezone.period_for_local(tz_ref_time, false)
    end

    if use_datetime?
      sec_msec = (msec == 0)? sec : Rational(sec * 1000 + msec, 1000)
      timezone_offset = timezone_code ?
        timezone_period.utc_total_offset_rational :
        Rational(Time.now.utc_offset, SECONDS_IN_DAY)
      return DateTime.civil(year, month, day, hour, min, sec_msec, timezone_offset)

    else
      return timezone_code ?
        timezone_period.to_utc(Time.utc(year, month, day, hour, min, sec, msec * 1000)) :
        Time.local(year, month, day, hour, min, sec, msec * 1000)
    end
  end

  def enable_tzinfo
    class << self
      undef_method :new_time if respond_to? :new_time
      define_method(:new_time, instance_method(:tzinfo_replac_new_time))
    end
  end

  def disable_tzinfo
    class << self
      undef_method :new_time
      define_method(:new_time, instance_method(:tzinfo_orig_new_time))
    end
  end
end

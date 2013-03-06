#!/usr/bin/env ruby -w
# encoding: UTF-8

#--
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

require 'date'

# Utilities for supporting the creation of exotic DateTimes (e.g. negative hours) in a way similar
# to the Java parser.
#
class << SDL4R
  
  # Enables the support of exotic dates (e.g. dates beyond end of month) by replacing
  # SDL4R#new_date_time by SDL4R#new_exotic_date_time
  def enable_exotic_dates
    def self.new_date_time(*args)
      new_exotic_date_time(*args)
    end
  end
  
  # Creates and returns a DateTime.
  # This method supports non-standard values for fields, like negative ones for hours. Contrarily to DateTime, negative
  # values can modify values of other fields.
  # Example
  #
  #   new_exotic_date_time(2010, 01, 01, -2, 55, 30) => 2009/12/31 22;55:30
  #
  # @param args [year, month, day, hour, min, sec, msec, timezone_code]
  def new_exotic_date_time(*args)
    amend_args = prepare_amend_args(args)

    year, month, day, hour, min, sec, msec, timezone_code = *args

    timezone_code ||= Time.now.zone
    sec_msec = (msec == 0)? sec : Rational(sec * 1000 + msec, 1000)

    date_time = DateTime.civil(year, month, day, hour, min, sec_msec, timezone_code)
    amend_exotic_date_time(date_time, amend_args)
  end


  private

  # Normal minimum values of the date fields
  TIME_FIELD_MINS = [nil, 1, 1, 0, 0, 0, 0, nil].freeze

  # Minimum of the unambiguous maximum values of date fields
  # (depending on the year and month, 29 can be ambiguous for days)
  TIME_FIELD_MIN_MAXS = [nil, 12, 28, 23, 59, 59, 999, nil].freeze


  # Separates the provided arguments of time creation
  # (year, month, day, hour, min, sec, msec, timezone_code) into:
  #
  # - the standard part of the arguments (e.g. 0 <= hour < 24)
  # - the differences between the original values and the standard ones
  #   (e.g. -5h => standard = 0h and amend = -5h)
  #   i.e. arguments to provide to #amend_exotic_date_time
  #
  # @param create_args
  #     modified by this method to only contain standard unambiguous values (e.g. 1 <= day <= 28,
  #     29 being ambiguous for some February months).
  #
  # @return arguments for #amend_date
  #
  def prepare_amend_args(create_args)
    amend_args = create_args.clone

    for i in 0..TIME_FIELD_MINS.length
      min = TIME_FIELD_MINS[i]
      max = TIME_FIELD_MIN_MAXS[i]
      val = create_args[i] || min

      if min and val < min
        create_args[i] = min
        amend_args[i] = val # for fields starting at 1, 0 is equivalent to 1 and -1 means "one day before the 1st"
      elsif max and val > max
        create_args[i] = max
        amend_args[i] = val - max
      else
        amend_args[i] = 0
      end
    end

    amend_args
  end

  MINUTES_IN_DAY = 24 * 60
  SECONDS_IN_DAY = MINUTES_IN_DAY * 60
  MILLISECONDS_IN_DAY = SECONDS_IN_DAY * 1000
  
  # Ruby 1.8 DateTime#sec_fraction returns a fraction of a day, whereas 1.9 returns a fraction of
  # a second. This coefficient allows to write:
  #
  #  DateTime.new.sec_fraction * SEC_FRACTION_COEFFICIENT # => fraction of a second
  #
  SEC_FRACTION_COEFFICIENT =
    if DateTime.civil(2009, 01, 02, 10, 50, Rational(11, 10)).sec_fraction == Rational(1, 10)
      1
    else
      SECONDS_IN_DAY
    end

  # Modifies +date_time+ by applying
  def amend_exotic_date_time(date_time, fields)
    year, month, day, hour, min, sec, msec = *fields

    if year != 0 or month != 0
      # as years and months have variable durations, we amend the fields separately
      date_time = DateTime.civil(
        date_time.year + year + ((date_time.month - 1 + month) / 12),
        (date_time.month - 1 + month) % 12 + 1,
        date_time.day,
        date_time.hour,
        date_time.min,
        date_time.sec + (date_time.sec_fraction * SEC_FRACTION_COEFFICIENT),
        date_time.zone)
    end

    if day != 0 or hour != 0 or min != 0 or sec != 0 or msec != 0
      # amending other fields consists in adding the proper number of days to the date
      date_time = date_time + (
        day +
        Rational(hour, 24) +
        Rational(min, MINUTES_IN_DAY) +
        Rational(sec, SECONDS_IN_DAY) +
        Rational(msec, MILLISECONDS_IN_DAY))
    end

    date_time
  end

end
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

require 'base64'
require 'bigdecimal'
require 'date'

require 'sdl4r/sdl4r_version'

# Utility methods and general constants for SDL4R.
#
# For more information about SDL4R, see the {link README file}[../../files/README.html]
# 
module SDL4R
  
  require 'sdl4r/writer'
  require 'sdl4r/serializer'

  MAX_INTEGER_32 = 2**31 - 1
  MIN_INTEGER_32 = -(2**31)
  
  MAX_INTEGER_64 = 2**63 - 1
  MIN_INTEGER_64 = -(2**63)

  ANONYMOUS_TAG_NAME = "content"
  ROOT_TAG_NAME = "root"

  # Creates an SDL string representation for a given object and returns it.
  # 
  def self.format(o)
    Writer.new.value(o).io.string
  end

  def self.format_time(time)
      s = "" # important as strftime() tends to return a US-ASCII string
      s << time.strftime("#{time.year}/%m/%d %H:%M:%S") # %Y tends to return "88" for 1988 in many implementations

      milliseconds = get_datetime_milliseconds(time)
      s << sprintf(".%03d", milliseconds) if milliseconds != 0

      zone_part = time.strftime("%z") # >> "+0130"  --  "%:z" is not supported by every interpreter
      unless zone_part.nil? or zone_part.empty? or zone_part == "+0000" or not zone_part =~ /[+-]\d+/
        zone_part.insert(3, ":")
        s << "-GMT" << zone_part
      end

      return s
  end

  @@use_datetime = true

  # Indicates whether DateTime is used to represent times. If false, Time is used instead. True by
  # default.
  def self.use_datetime?
    @@use_datetime
  end

  # Sets whether DateTime should be used for representing times at parsing.
  # If set to false, Time will be used instead (true by default).
  #
  def self.use_datetime=(bool)
    @@use_datetime = bool
  end
  
  @@use_exotic_dates = false
    
  # Enables the support of exotic dates (e.g. dates beyond end of month).
  # DateTime creation will be slower than the normal bare and strict creation.
  # The same feature for Time is not supported yet.
  # 
  def self.enable_exotic_dates
    require 'sdl4r/sdl4r_date'
    @@use_exotic_dates = true
  end

  # Creates and returns the object representing a time (DateTime by default).
  # This method is called by the Parser class.
  #
  # See #use_datetime=
  #
  def self.new_time(year, month, day, hour, min, sec, msec, timezone_code)
    if @@use_datetime
      timezone_code ||= Time.now.zone
      sec_msec = (msec == 0)? sec : Rational(sec * 1000 + msec, 1000)
      unless @@use_exotic_dates
        return DateTime.civil(year, month, day, hour, min, sec_msec, timezone_code)
      else
        return new_exotic_date_time(year, month, day, hour, min, sec, timezone_code)
      end

    else
      if timezone_code =~ /\A(?:GMT|UTC)([+-]\d+:\d+)\Z/
        timezone_code = $1
      end
      timezone_offset = Time.zone_offset(timezone_code, year) if timezone_code
      if timezone_offset
        timezone_offset_hour = timezone_offset.abs / 3600
        timezone_offset_min = (timezone_offset.abs % 3600) / 60
        return Time.xmlschema(
          sprintf(
            "%d-%02d-%02dT%02d:%02d:%02d.%03d#{timezone_offset >= 0 ? '+' : '-'}%02d:%02d",
            year, month, day, hour, min, sec, msec, timezone_offset_hour, timezone_offset_min))

      else
        return Time.local(year, month, day, hour, min, sec, msec * 1000)
      end
    end
  end
  
  # Coerce the type to a standard SDL type or raises an ArgumentError.
  #
  # Returns +o+ if of the following classes:
  # NilClass, String, Numeric, Float, TrueClass, FalseClass, Date, DateTime, Time,
  # SdlTimeSpan, SdlBinary,
  #
  # Rationals are turned into Floats using Rational#to_f.
  # Symbols are turned into Strings using Symbol#to_s.
  #
  def self.coerce_or_fail(o)
    case o

    when Rational
      return o.to_f

    when Symbol
      return o.to_s

    when NilClass,
        String,
        Numeric,
        Float,
        TrueClass,
        FalseClass,
        Date,
        DateTime,
        Time,
        SdlTimeSpan,
        SdlBinary
      return o

    end

    raise ArgumentError, "#{o.class.name} is not coercible to an SDL type"
  end

  # Indicates whether 'o' is coercible to a SDL literal type.
  # See #coerce_or_fail
  #
  def self.is_coercible?(o)
    begin
      coerce_or_fail(o)
      true
      
    rescue ArgumentError
      false
    end
  end

  # We disable the warnings as Ruby 1.8.7 prints one for the tested regex. We don't need this
  # warning as we are precisely testing whether this regular expression works.
  # Unfortunately, creating the regex with Regexp.new() doesn't help: we would have liked getting a
  # RegexpError.
  begin
    old_verbose, $VERBOSE = $VERBOSE, nil
    @@UNICODE_REGEXP_SUPPORTED = ('é' =~ Regexp.new("\\p{Alnum}")) != nil
  ensure
    $VERBOSE = old_verbose
  end

  def self.supports_unicode_identifiers?
    @@UNICODE_REGEXP_SUPPORTED
  end

  IDENTIFIER_START_CLASS = @@UNICODE_REGEXP_SUPPORTED ? '[\\p{Alpha}_]' : '[a-zA-Z_]'

  # Matches the first character of a valid SDL identifier.
  IDENTIFIER_START_REGEXP =
    @@UNICODE_REGEXP_SUPPORTED ? /\A#{IDENTIFIER_START_CLASS}/u : /\A#{IDENTIFIER_START_CLASS}/

  IDENTIFIER_PART_CLASS =
    @@UNICODE_REGEXP_SUPPORTED ? '[\\p{Alnum}_\\-\\.$]' : '[\\w\\-\\.$]'

  # Matches characters of a valid SDL identifier after the first one.
  # Works with one character long strings.
  IDENTIFIER_PART_REGEXP =
    @@UNICODE_REGEXP_SUPPORTED ?
      /\A#{IDENTIFIER_PART_CLASS}\Z/u :
      /\A#{IDENTIFIER_PART_CLASS}\Z/

  # Matches a valid SDL identifier (start to end).
  IDENTIFIER_REGEXP = @@UNICODE_REGEXP_SUPPORTED ?
    /\A#{IDENTIFIER_START_CLASS}#{IDENTIFIER_PART_CLASS}*\Z/u :
    /\A#{IDENTIFIER_START_CLASS}#{IDENTIFIER_PART_CLASS}*\Z/
  
  # Validates an SDL identifier String.  SDL Identifiers must start with a
  # Unicode letter or underscore (_) and contain only unicode letters,
  # digits, underscores (_), dashes(-), periods (.) and dollar signs ($).
  # 
  # == Raises
  # ArgumentError if the identifier is not legal
  #
  # TODO: support UTF-8 identifiers
  #
  def self.validate_identifier(identifier)
    if identifier.nil? or identifier.empty?
      raise ArgumentError, "SDL identifiers cannot be null or empty."
    end

    # in Java, was if(!Character.isJavaIdentifierStart(identifier.charAt(0)))
    unless identifier =~ IDENTIFIER_START_REGEXP
      raise ArgumentError,
        "'" + identifier[/^./] +
        "' is not a legal first character for an SDL identifier. " +
        "SDL Identifiers must start with a unicode letter or " +
        "an underscore (_). (identifier=<#{identifier}>)"
    end

    unless identifier.length == 1 or identifier =~ IDENTIFIER_REGEXP
      for i in 1..identifier.length
        unless identifier[i..i] =~ IDENTIFIER_PART_REGEXP
          raise ArgumentError,
            "'" + identifier[i..i] + 
            "' is not a legal character for an SDL identifier. " +
            "SDL Identifiers must start with a unicode letter or " +
            "underscore (_) followed by 0 or more unicode " +
            "letters, digits, underscores (_), dashes (-), periodss (.) and dollar signs ($)"
        end
      end
    end
  end

  # Returns whether the specified SDL identifier is valid.
  # See SDL4R#validate_identifier.
  #
  def self.valid_identifier?(identifier)
    !IDENTIFIER_REGEXP.match(identifier).nil?
  end

  # Creates and returns a tag named "root" and add all the tags specified in the given +input+.
  #
  # +input+:: String, IO, Pathname or URI.
  #
  #   root = SDL4R::read(<<EOS
  #   planets {
  #     earth area_km2=510900000
  #     mars
  #   }
  #   EOS
  #   )
  #
  #   root = SDL4R::read(Pathname.new("my_dir/my_file.sdl"))
  #
  #   IO.open("my_dir/my_file.sdl", "r") { |io|
  #     root = SDL4R::read(io)
  #   }
  #   
  #   root = SDL4R::read(URI.new("http://my_site/my_file.sdl"))
  #
  def self.read(input)
    Tag.new(ROOT_TAG_NAME).read(input)
  end

  # Parses and returns the value corresponding with the specified SDL literal.
  #
  #   SDL4R.to_value("\"abcd\"") # => "abcd"
  #   SDL4R.to_value("1") # => 1
  #   SDL4R.to_value("null") # => nil
  #
  def self.to_value(s)
    raise ArgumentError, "'s' cannot be null" if s.nil?
    return read(s).child.value
  end

  # Parse the string of values and return a list.  The string is handled
  # as if it is the values portion of an SDL tag.
	#
	# Example
	#
	#   array = SDL4R.to_value_array("1 true 12:24:01")
	#
	# Will return an int, a boolean, and a time span.
	#
  def self.to_value_array(s)
    raise ArgumentError, "'s' cannot be null" if s.nil?
    return read(s).child.values
  end

	# Parse a string representing the attributes portion of an SDL tag
	# and return the results as a map.
	#
	# Example
	# 
	#   hash = SDL4R.to_attribute_hash("value=1 debugging=on time=12:24:01");
	#
	#   # { "value" => 1, "debugging" => true, "time" => SdlTimeSpan.new(12, 24, 01) }
	#
  def self.to_attribute_hash(s)
    raise ArgumentError, "'s' cannot be null" if s.nil?
    return read("atts " + s).child.attributes
  end

  # Loads the specified 'input' and deserializes into the returned object.
  #
  # _input_:: an input as accepted by SDL4R#read or a Tag.
  #
  # example:
  #
  #   top = SDL4R::load(<<EOS
  #   food name="chili con carne" {
  #     ingredient "beans"
  #     ingredient "chili"
  #     ingredient "cheese"
  #     note 8.9
  #   }
  #   EOS
  #   )
  #
  #   top.food.name # => "chili con carne"
  #   top.food.ingredient # => ["beans", "chili", "cheese"]
  #   top.food.note # => 8.9
  #
  def self.load(input)
    if input.is_a? Tag
      tag = input
    else
      tag = read(input)
    end

    return Serializer.new.deserialize(tag)
  end

  # Dumps the specified object to a given output or returns the corresponding SDL string if output is +nil+.
  #
  # @param o Object dumped into SDL (via AbstractWriter#write) and considered as the root element
  # @param output AbstractWriter or any legal input of Writer#new
  #
  # @example
  #
  #     food = OpenStruct.new(:name => 'french fries', 'comment' => 'eat with bier')
  #     food.fan = OpenStruct.new(:firstname => 'Homer')
  #
  #     puts SDL4R::dump(:food => food)
  #
  #   gives us
  #
  #     food comment="eat with bier" name="french fries" {
  #       fan firstname="Homer"
  #     }
  #
  def self.dump(o, output = nil)
    writer = (output.is_a? AbstractWriter) ? output : Writer.new(output)
		writer.write(o)

    if output.nil?
			writer.io.string
    else
			output
    end
  end

  # The following is a not so readable way to implement module private methods in Ruby: we add
  # private methods to the singleton class of +self+ i.e. the SDL4R module.
  class << self
    private

    SECONDS_IN_DAY = 24 * 3600 # :nodoc:

    # Returns the microseconds component of the given DateTime or Time.
    # DateTime and Time having vastly different behaviors between themselves or in Ruby 1.8 and 1.9,
    # this method makes an attemps at getting this component out of the specified object.
    # 
    # In particular, DateTime.sec_fraction() (which I used before) returns incorrect values in, at
    # least, some revisions of Ruby 1.9.
    #
    def get_datetime_milliseconds(datetime)
      if datetime.respond_to?(:usec)
        return (datetime.usec / 1000.0).round
      else
        # Here don't believe that we could use '%3N' to get the milliseconds directly: the "3" is
        # ignored for DateTime.strftime() in Ruby 1.8.
        nanoseconds = datetime.strftime("%N").to_i
        return (nanoseconds / 1000000).round
      end
    end

  end

end

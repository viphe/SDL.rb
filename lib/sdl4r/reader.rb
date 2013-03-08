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

  require 'stringio'
  require 'date'

  require 'sdl4r/sdl4r'
  require 'sdl4r/sdl_time_span'
  require 'sdl4r/sdl_binary'
  require 'sdl4r/tokenizer'
  require 'sdl4r/element'
  require 'sdl4r/reader_with_element'
  require 'sdl4r/abstract_reader'

  # Implementation of a pull parser for SDL designed after the model of Nokogiri::XML::Reader.
  #
  class Reader
    include ReaderWithElement, AbstractReader

    # @private
    def self.add_values_handler(map, handler)
      map[:NULL] = handler
      map[:INTEGER] = handler
      map[:FLOAT] = handler
      map[:BOOLEAN] = handler
      map[:CHARACTER] = handler
      map[:INLINE_BACKQUOTE_STRING] = handler
      map[:INLINE_DOUBLE_QUOTE_STRING] = handler
      map[:MULTILINE_BACKQUOTE_STRING_START] = handler
      map[:MULTILINE_DOUBLE_QUOTE_STRING_START] = handler
      map[:INLINE_BINARY] = handler
      map[:MULTILINE_BINARY_START] = handler
      map[:DATE] = handler
      map[:TIME_OR_TIMESPAN] = handler
    end

    # @private
    @@SKIP_PROC = lambda { |reader| false } # skips current token
    # @private
    @@ON_SELF_CLOSING_TAG_PROG = lambda { |reader| reader.on_self_closing_tag }

    # @private
    @@comment_handler_set = {
      :INLINE_COMMENT => lambda { |reader| reader.on_simple_comment },
      :ONE_LINE_COMMENT => lambda { |reader| reader.on_simple_comment },
      :MULTILINE_COMMENT_START => lambda { |reader| reader.on_multiline_comment },
    }

    # Handlers that work the same at the top level or in any normal tag body.
    # @private
    @@common_tag_set = {
      :WHITESPACE => @@SKIP_PROC,
      :EOL => @@SKIP_PROC,
      :SEMICOLON => @@SKIP_PROC,
      :IDENTIFIER => lambda { |reader| reader.on_tag_start },
    }

    # The handlers are object with #call() (like Proc, etc) that should return false if the
    # corresponding token is ignored, true otherwise.
    # @private
    #
    @@handler_sets = {}

    @@handler_sets[:top] = {
      :EOF => lambda { |reader| reader.on_eof },
    }
    @@handler_sets[:top].merge!(@@common_tag_set)
    @@handler_sets[:top].merge!(@@comment_handler_set)
    add_values_handler(@@handler_sets[:top], lambda { |reader| reader.on_anonymous_value })

    @@handler_sets[:tag_values] = {
      :WHITESPACE => @@SKIP_PROC,
      :LINE_CONTINUATION => @@SKIP_PROC,
      :IDENTIFIER => lambda { |reader| reader.on_attribute },
      :EOL => @@ON_SELF_CLOSING_TAG_PROG,
      :SEMICOLON => @@ON_SELF_CLOSING_TAG_PROG,
      :BLOCK_START => lambda { |reader| reader.on_tag_body_start },
      :EOF => @@ON_SELF_CLOSING_TAG_PROG,
    }
    @@handler_sets[:tag_values].merge!(@@comment_handler_set)
    add_values_handler(@@handler_sets[:tag_values], lambda { |reader| reader.on_value })

    @@handler_sets[:tag_attributes] = {
      :WHITESPACE => @@SKIP_PROC,
      :LINE_CONTINUATION => @@SKIP_PROC,
      :IDENTIFIER => lambda { |reader| reader.on_attribute },
      :EOL => @@ON_SELF_CLOSING_TAG_PROG,
      :SEMICOLON => @@ON_SELF_CLOSING_TAG_PROG,
      :BLOCK_START => lambda { |reader| reader.on_tag_body_start },
      :EOF => @@ON_SELF_CLOSING_TAG_PROG,
    }
    @@handler_sets[:tag_attributes].merge!(@@comment_handler_set)

    @@handler_sets[:tag_body] = {
      :BLOCK_END => lambda { |reader| reader.on_tag_body_end },
    }
    @@handler_sets[:tag_body].merge!(@@common_tag_set)
    @@handler_sets[:tag_body].merge!(@@comment_handler_set)
    add_values_handler(@@handler_sets[:tag_body], lambda { |reader| reader.on_anonymous_value })

    @@handler_sets[:eof] = {}

    # @private
    @@value_handlers = {
      :NULL => lambda { |s, reader| nil },
      :INTEGER => lambda { |s, reader| reader.parse_integer(s) },
      :FLOAT => lambda { |s, reader| reader.parse_float(s) },
      :BOOLEAN => lambda { |s, reader| (s =~ /\A(?:true|on)\Z/) ? true : false },
      :CHARACTER => lambda { |s, reader| reader.parse_character(s) },
      :INLINE_BACKQUOTE_STRING => lambda { |s, reader| s },
      :INLINE_DOUBLE_QUOTE_STRING => lambda { |s, reader| reader.parse_double_quote_string(s) },
      :MULTILINE_BACKQUOTE_STRING_START =>
        lambda { |s, reader| reader.parse_multiline_backquote_string(s) },
      :MULTILINE_DOUBLE_QUOTE_STRING_START =>
        lambda { |s, reader| reader.parse_multiline_double_quote_string(s) },
      :INLINE_BINARY => lambda { |s, reader| SdlBinary.decode64(s) },
      :MULTILINE_BINARY_START => lambda { |s, reader| reader.parse_multiline_binary(s) },
      :DATE => lambda { |s, reader| reader.parse_date(s) },
      :TIME_OR_TIMESPAN => lambda { |s, reader| reader.parse_time_span(s) },
    }

    # Type of the traversed SDL node (e.g. TYPE_ELEMENT).
    attr_reader :node_type

    # Prefix (namespace) of the traversed SDL node.
    attr_reader :prefix

    # Name of the traversed SDL node.
    attr_reader :name

    # Depth of the current SDL node. Depth of top nodes is 1 (0 would be the root that the Reader
    # doesn't traverse).
    attr_reader :depth

    attr_reader :element
    protected :element

    def initialize(io)
      raise ArgumentError, 'io == nil' if io.nil?
      raise ArgumentError, 'io is not an IO' unless io.respond_to?(:gets)

      @io = io
      @tokenizer = Tokenizer.new(@io)
      @element = nil
      @depth = 1

      clear_node()
      set_mode(:top)
    end

    def rewindable?
      @io.is_a? StringIO or @io.is_a? File
    end

    def rewind
      @io.rewind
    end

    def clear_node
      @node_type = nil
      @prefix = nil
      @name = nil
    end
    private :clear_node

    def values
      if @element
        values = @element.values
        values.empty? ? nil : values.clone
      else
        @value
      end
    end
    alias_method :value, :values

    def values?
      if @element
        !@element.values.empty?
      else
        !@value.nil?
      end
    end
    alias_method :value?, :values?

    def self.from_io(io)
      self.new(io)
    end

    def self.from_memory(s)
      self.new(StringIO.new(s))
    end

    # Reads the next node in the SDL structure.
    #
    # @example
    #   open("sample.sdl") do |io|
    #     reader = SDL4R::Reader.from_io(io)
    #     while node = reader.read
    #       puts node.node_type
    #     end
    #   end
    #
    # @return [Reader] returns a Reader if a new node has been reached or +nil+ if the end of file has been reached.
    def read
      clear_node

      node = nil

      while @tokenizer.read
        handler = @handler_set[@tokenizer.token_type]
        unless handler
          raise_unexpected_token
        end
        if handler.call(self)
          node = self if @node_type # otherwise, we reached the end of the file
          break
        end
      end

      node
    end

    # @private
    def raise_unexpected_token
      @tokenizer.raise_parse_error(
        "unexpected token #{@tokenizer.token_type} #{@tokenizer.token.inspect}",
        @tokenizer.token_line_no,
        @tokenizer.token_pos)
    end

    def set_mode(mode)
      handler_set = @@handler_sets[mode]
      raise ArgumentError, "unknown mode #{mode.to_s}" unless handler_set
      @mode = mode
      @handler_set = handler_set
    end
    protected :set_mode

    # @private
    def on_simple_comment # :nodoc:
#        @node_type = TYPE_COMMENT
      false
    end

    # @private
    def on_eof # :nodoc:
      @node_type = nil
      true
    end

    # @private
    def on_multiline_comment # :nodoc:
#        @node_type = TYPE_COMMENT
      @value = @tokenizer.token

      while @tokenizer.read
        case @tokenizer.token_type
        when :EOL
          @value << ?\n
        when :MULTILINE_COMMENT_PART
          @value << @tokenizer.token
        when :MULTILINE_COMMENT_END
          @value << @tokenizer.token
          break
        else
          raise_unexpected_token
        end
      end

      false
    end

    # @private
    def on_tag_start # :nodoc:
      read_name
      set_mode :tag_values
      @element = Element.new @prefix, @name

      false
    end

    # @private
    def on_self_closing_tag # :nodoc:
      @node_type = TYPE_ELEMENT
      @prefix = @element.prefix
      @name = @element.name
      @element.self_closing = true
      set_mode(@depth <= 1 ? :top : :tag_body)
    end

    # @private
    def on_attribute # :nodoc:
      read_name
      read_equal
      read_value
      set_mode :tag_attributes
      @element.add_attribute(@prefix, @name, @value)

      false
    end

    # @private
    def on_value # :nodoc:
      read_value
      set_mode :tag_values
      @element.add_value(@value)

      false
    end

    # Should only be called from :top or :tag_body modes.
    # @private
    def on_anonymous_value # :nodoc:
      set_mode :tag_values
      @element = Element.new '', SDL4R::ANONYMOUS_TAG_NAME

      on_value
    end

    # @private
    def on_tag_body_start # :nodoc:
      @node_type = TYPE_ELEMENT
      @prefix = @element.prefix
      @name = @element.name
      @depth += 1
      set_mode :tag_body

      true
    end

    # @private
    def on_tag_body_end # :nodoc:
      if @depth <= 1
        raise "unexpected end of tag"
      end

      clear_node
      @node_type = TYPE_END_ELEMENT
      @depth -= 1
      set_mode(@depth <= 1 ? :top : :tag_body)

      true
    end

    # @private
    def parse_double_quote_string(s)
      return s if s.empty?

      string = ""
      escaped = false

      s.each_char do |c|
        if escaped
          escaped = false

          case c
          when "\\", "\""
            string << c
          when "n"
            string << ?\n
          when "r"
            string << ?\r
          when "t"
            string << ?\t
          else
            @tokenizer.raise_parse_error("Illegal escape character in string literal: '#{c}'.")
          end

        elsif c == "\\"
          escaped = true

        else
          string << c
        end
      end

      @tokenizer.raise_parse_error("orphan backslash") if escaped

      string
    end

    # @private
    def parse_multiline_string(first_string, part_token_type, end_token_type)
      string = ""
      string << first_string

      loop do
        case @tokenizer.read
        when :EOL
          # skip
        when part_token_type
          string << @tokenizer.token
        when end_token_type
          string << @tokenizer.token
          break
        else
          raise_unexpected_token
        end
      end

      string
    end
    private :parse_multiline_string

    # @private
    def parse_multiline_backquote_string(s)
      parse_multiline_string s, :MULTILINE_BACKQUOTE_STRING_PART, :MULTILINE_BACKQUOTE_STRING_END
    end

    # @private
    def parse_multiline_double_quote_string(s)
      parse_double_quote_string(
        parse_multiline_string(
          s, :MULTILINE_DOUBLE_QUOTE_STRING_PART, :MULTILINE_DOUBLE_QUOTE_STRING_END))
    end

    # @private
    def parse_multiline_binary(s)
      literal = parse_multiline_string s, :MULTILINE_BINARY_PART, :MULTILINE_BINARY_END
      return SdlBinary.decode64(literal)
    end

    # @private
    def parse_character(s)
      case s
      when /\A.\Z/
        s
      when "\\\\"
        "\\"
      when "\\'"
        "'"
      when "\\n"
        "\n"
      when "\\r"
        "\r"
      when "\\t"
        "\t"
      else
        raise "illegal character literal #{s.inspect}"
      end
    end

    # @private
    def parse_integer(s)
      if s =~ /\A([^L]+)L\Z/i
        return Integer($1)
      else
        return Integer(s)
      end
    end

    # @private
    def parse_float(s)
      if s =~ /\A([^BDF]+)BD\Z/i
        return BigDecimal($1)
      elsif s =~ /\A([^BDF]+)[FD]\Z/i
        return Float($1) rescue @tokenizer.raise_parse_error("not a float '#{$1}'")
      else
        return Float(s) rescue @tokenizer.raise_parse_error("not a float '#{s}'")
      end
    end

    # Parses the +literal+ into a returned Date object.
    #
    # Raises an ArgumentError if +literal+ has a bad format.
    #
    # @private
    def parse_date(literal)
      # here, we're being stricter than strptime() alone as we forbid trailing chars (also faster)
      if literal =~ /\A(-?\d+)\/(\d+)\/(\d+)\Z/
        date_year = $1.to_i
        date_month = $2.to_i
        date_day = $3.to_i

        skip_whitespaces(false)

        # Check whether the next tag is the time part
        if @tokenizer.token_type == :TIME_OR_TIMESPAN
          # Is it a time or timespan?
          day, hour, min, sec, msec, zone =
            parse_time_span_and_time_zone(@tokenizer.token, true, true)

          if day
            @tokenizer.unread
            return Date.civil(date_year, date_month, date_day)
          else
            return new_time(date_year, date_month, date_day, hour, min, sec, msec, zone)
          end

        else
          @tokenizer.unread
          return Date.civil(date_year, date_month, date_day)
        end

      else
        raise ArgumentError, "Malformed Date <#{literal}>"
      end
    end

    # Parses +literal+ (String) into the corresponding SDLTimeSpan, which is then
    # returned.
    #
    # Raises an ArgumentError if the literal is not a correct timespan literal.
    #
    # @private
    def parse_time_span(literal)
      days, hours, minutes, seconds, milliseconds, zone_code =
        parse_time_span_and_time_zone(literal, true, false)

      if zone_code
        @tokenizer.raise_parse_error("got a time when expecting a timespan: \"#{literal}\"")
      end

      return SDL4R::SdlTimeSpan.new(days || 0, hours, minutes, seconds, milliseconds)
    end

    private

    # Parses the given literal into a returned array
    # [days, hours, minutes, seconds, milliseconds, zone_code].
    # 'days', 'hours', 'minutes', 'seconds', 'milliseconds' are integers.
    # 'days' is +nil+ if not specified in +literal+.
    # 'seconds' and 'milliseconds' are equal to 0 if they're not specified in +literal+.
    # 'zone_code' (string) is equal to nil if not specified.
    #
    # +allowDays+ indicates whether the specification of days is allowed
    # in +literal+
    # +allowTimeZone+ indicates whether the specification of the timeZone is
    # allowed in +literal+
    #
    # All components are returned disregarding the values of +allowDays+ and
    # +allowTimeZone+.
    #
    # Raises an ArgumentError if +literal+ has a bad format.
    def parse_time_span_and_time_zone(literal, allowDays, allowTimeZone)
      overall_sign = (literal =~ /^-/)? -1 : +1

      if literal =~ /\A(([+\-]?\d+)d:)/
        if allowDays
          days = Integer($2)
          time_part = literal[($1.length)..-1]
        else
          # detected a day specification in a pure time literal
          raise ArgumentError, "unexpected day specification in #{literal}"
        end
      else
        days = nil
        time_part = literal
      end

      # We have to parse the string ourselves because AFAIK :
      #	- strptime() can't parse milliseconds
      #	- strptime() can't parse the time zone custom offset (CET+02:30)
      #	- strptime() accepts trailing chars
      #		(e.g. "12:24-xyz@" ==> "xyz@" is obviously wrong but strptime()
      #		 won't mind)
      if /\A([+-]?\d+):(\d+)(?::(\d+)(?:\.(\d+))?)?
          (?:-([a-zA-Z0-9\/_]+(?:[+\-]\d+(?::\d+)?)?))?\Z/ix =~ time_part
        hours = $1.to_i
        minutes = $2.to_i
        seconds = $3 ? $3.to_i : 0
        milliseconds =
          if $4
            millisecond_part = ($4)? $4.ljust(3, '0') : nil
            millisecond_part.to_i
          else
            0
          end

        if $5 and not allowTimeZone
          raise ArgumentError, "unexpected time zone specification in #{literal}"
        end

        zone_code = $5 # might be nil

        if not allowDays and $1 =~ /\A[+-]/
          # unexpected timeSpan syntax
          raise ArgumentError, "unexpected sign on hours : #{literal}"
        end

        # take the sign into account
        if overall_sign == -1
          hours = -hours if days # otherwise the sign is already applied to the hours
          minutes = -minutes
          seconds = -seconds
          milliseconds = -milliseconds
        end

        return [ days, hours, minutes, seconds, milliseconds, zone_code ]

      else
        raise ArgumentError, "bad time component : #{literal}"
      end
    end

    def skip_whitespaces(allow_line_continuations = false)
      while token_type = @tokenizer.read
        case token_type
          when :WHITESPACE
            # skip
          when :LINE_CONTINUATION
            break unless allow_line_continuations
          else
            break
        end
      end
    end

    # @private
    def read_equal
      skip_whitespaces(false)
      unless @tokenizer.token_type == :EQUAL
        raise_unexpected_token
      end
      skip_whitespaces(true)
    end

    # @private
    def read_name
      @name = @tokenizer.token

      if @tokenizer.read == :COLON
        # Namespace + Name (except syntax error)
        if @tokenizer.read == :IDENTIFIER
          @prefix = @name
          @name = @tokenizer.token

        else
          raise_unexpected_token
        end

      else # Just a Name, it seems
        @tokenizer.unread
        @prefix = ''
      end

      @name
    end

    # @private
    def read_value
      handler = @@value_handlers[@tokenizer.token_type]
      raise_unexpected_token unless handler
      @value = handler.call(@tokenizer.token, self)
      @value
    end
  end
end

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
  
  # Forward-only, non-cached SDL writer to IO.
  #
  class Writer
    require 'sdl4r/abstract_writer'
    
    include AbstractWriter
    
    require 'sdl4r/invalid_operation_error'
    
    DEFAULT_OPTIONS = {
      :indent_text => "\t",
      :eol => "\n",
      :string_quote => '"',
    }
    
    def initialize_options(options)
      if options
        options = DEFAULT_OPTIONS.merge(options)
      else
        options = DEFAULT_OPTIONS
      end
      
      @indent_text = options[:indent_text]
      @eol = options[:eol]
      @string_quote = options[:string_quote]
      raise ArgumentError,
        "invalid string quote <#@string_quote>" unless @string_quote =~ /\A["`]\Z/
    end
    
    # @param [IO, Pathname, String] out
    #   the IO, Pathname of the file or String to write to (defaults to a StringIO)
    # @param [Hash] options options of the created Writer
    # @option [String] options :indent_text text used in order to indent lines (default: "\t")
    # @option [String] options :eol end-of-line (default: "\n")
    # @option [String] options :string_quote either '"' or '`'
    # @param [ObjectMapper] object_mapper support object for serialization
    #
    def initialize(out = nil, options = nil, object_mapper = ObjectMapper.new)
      out, options = nil, out if options.nil? and out.is_a? Hash

      self.object_mapper = object_mapper

      initialize_options(options)
      
      @depth = 0

      # Possible statuses:
      #  :top           root level
      #  :body          inside a tag body,
      #  :anonymous     just after the declaration of an anonymous tag
      #  :values        after the tag name and before attributes
      #  :attributes    after the first attribute before end of tag or body start
      @status = :top
      
      @last_value_was_date = false
      
      case out
      when Pathname
        @io = out.open('w')
        autoclose = true
      when String
        @io = StringIO.new(out)
        autoclose = true
      when nil
        @io = StringIO.new('')
        autoclose = true
      else
        @io = out
        autoclose = false
      end
      
      if block_given?
        yield self
        close if autoclose
      end
    end
    
    # The underlying IO.
    attr_reader :io, :depth
    
    # Closes the underlying IO.
    def close
      @io.close
    end
    
    def indent
      @depth.times { @io << @indent_text }
    end
    private :indent
    
    def new_line
      @io << @eol
    end
    private :new_line
    
    # Writes the declaration of a tag.
    # No validity check as for legal characters is performed on +name+ and +namespace+.
    #
    # @overload start_element(name)
    #   @param [String, Symbol] name (if empty, emits an anonymous tag)
    # @overload start_element(namespace, name)
    #   @param [String, Symbol] name
    #   @param [String, Symbol] namespace
    #   
    # @return [self]
    #
    def start_element(namespace, name = nil)
      namespace, name = '', namespace unless name

      start_body if [:anonymous, :values, :attributes].include? @status
      indent

      if namespace and not namespace.to_s.empty?
        raise ArgumentError, 'empty element name' if name.to_s.empty?
        
        @io << namespace << ':' << name
        @status = :values
        
      else
        name = name.to_s
        name = SDL4R::ANONYMOUS_TAG_NAME if name.empty?
        
        if name == SDL4R::ANONYMOUS_TAG_NAME
          # No name is emitted, of course.
          @status = :anonymous
        else
          @io << name
          @status = :values
        end
      end

      @depth += 1

      self
    end
    
    # Ends the current tag, closing its body if necessary.
    def end_element
      raise InvalidOperationError, @status if @status == :top

      if @status == :body
        end_body
      else
        @depth -= 1
        new_line
        @status = @depth == 0 ? :top : :body
      end

      @last_value_was_date = false
    end
    
    # Writes the start of a tag body to the underlying IO.
    # @return [self]
    def start_body
      @io << ' ' unless [:top, :body, :anonymous].include? @status
      @io << '{'
      new_line
      @status = :body
      self
    end
    
    # Writes the end of a tag body to the underlying IO.
    # @return [self]
    def end_body
      raise InvalidOperationError, 'can\'t end body at top level' if @depth <= 0

      @depth -= 1

      @io << @eol unless @status == :body
      indent
      @io << '}'
      new_line
      @status = @depth == 0 ? :top : :body
      self
    end
    
    # Writes the provided object directly to the underlying IO. Allows to write raw text to the IO.
    def <<(o)
      @io << o
      self
    end

    BASE64_WRAP_LINE_LENGTH = 72
    
    # Writes one value or several.
    #
    def value(*values)
      # if not at the start of a tag, start an anonymous one if possible
      start_element(SDL4R::ANONYMOUS_TAG_NAME) if [:top, :body].include? @status
      
      raise InvalidOperationError, @status unless [:anonymous, :values].include? @status
      
      values.each do |v|
        @io << ' ' unless @status == :anonymous
        
        if @last_value_was_date and v.is_a? SdlTimeSpan
          # We force the writing of the days, otherwise we create an ambiguity with a timestamp
          # literal.
          @io << v.to_s(true)
          @last_value_was_date = false
        else
          format_literal(v)
          @last_value_was_date = (v.is_a? Date)
        end
        
        @status = :values
      end
      
      self
    end
    
    # Writes the specified attribute.
    #
    # @overload attribute(name)
    #   @param [String, Symbol] name
    #   @param [Object] value attribute value
    #   
    # @overload attribute(namespace, name)
    #   @param [String, Symbol] name
    #   @param [String, Symbol] namespace
    #   @param [Object] value attribute value
    # 
    def attribute(namespace, name, value = MISSING_PARAMETER)
      raise "bad arguments #{namespace.inspect}, #{name.inspect}" if namespace.nil? or name.nil?
      raise InvalidOperationError, @status unless [:values, :attributes].include? @status
      
      value, name, namespace = name, namespace, '' if MISSING_PARAMETER.equal? value
      namespace = namespace.id2name if namespace.is_a? Symbol
      name = name.id2name if name.is_a? Symbol
      
      @io << ' ' unless @status == :anonymous
      
      unless namespace.empty?
        @io << namespace << ':'
      end
      @io << name
      
      @io << '='
      
      format_literal(value)
      
      @status = :attributes
      
      self
    end
    
    # Converts the given SDL value into a SDL literal and writes it to the underlying stream.
    def format_literal(o)
      case o
      when String
        write_string(o)

      when Symbol
        write_string(o.to_s)

      when Bignum
        @io << o.to_s << "BD"

      when Integer
        if MIN_INTEGER_32 <= o and o <= MAX_INTEGER_32
          @io << o.to_s
        elsif MIN_INTEGER_64 <= o and o <= MAX_INTEGER_64
          @io << o.to_s << "L"
        else
          @io << o.to_s << "BD"
        end

      when Float
        @io << o.to_s << "F"

      when Rational
        @io << o.to_f.to_s << "F"

      when BigDecimal
        s = o.to_s('F')
        s.sub!(/\.0$/, "")
        @io << "#{s}BD"

      when NilClass
        @io << "null"

      when SdlBinary
        encoded_o = Base64.encode64(o.bytes)
        encoded_o.gsub!(/[\r\n]/m, "") # Remove the EOL inserted every 60 chars

        if encoded_o.length > BASE64_WRAP_LINE_LENGTH
          @io << "["
          new_line

          @depth += 1
          wrap_lines_in_ascii(encoded_o)
          @depth -= 1
          new_line

          indent
          @io << "]"

        else
          @io << "["
          @io << encoded_o
          @io << "]"
        end

      # Below, we use "#{o.year}" instead of "%Y" because "%Y" always emit 4 chars at least even if
      # the date is before 1000.
      when DateTime, Time
        @io << SDL4R::format_time(o)

      when Date
        @io << "#{o.strftime("#{o.year}/%m/%d")}"

      else
        @io << o.to_s
      end
      
      self
    end

    # Returns the specified string 's' formatted as a SDL string.
    # See SDL4R#format.
    # 
    # @param [String] quote_char the quote character or nil to have no quotes at all.
    #
    def write_string(s, quote_char = @string_quote)
        if quote_char
          @io << quote_char << escape(s) << quote_char
        else
          @io << escape(s)
        end
    end
    
    private

    # Wraps lines in "s" (by modifying it). This method only supports 1-byte character strings.
    #
    def wrap_lines_in_ascii(s, line_length = BASE64_WRAP_LINE_LENGTH)
      i = 0
      while i < s.size
        new_line if i > 0
        indent

        @io << s[i...(i + line_length)]
        
        i += line_length
      end
    end

    ESCAPED_QUOTES = {
      "\"" => "\\\"",
      "'" => "\\'",
      "`" => "\\`",
    }

    ESCAPED_CHARS = {
      "\\" => "\\\\",
      "\t" => "\\t",
      "\r" => "\\r",
      "\n" => "\\n",
    }
    ESCAPED_CHARS.merge!(ESCAPED_QUOTES)

    # Writes an escaped version of +s+ (i.e. where characters which need to be
    # escaped, are escaped).
    #
    def escape(s, quote_char = nil)
      escaped_s = ""

      s.each_char { |c|
        escaped_char = ESCAPED_CHARS[c]
        if escaped_char
          if ESCAPED_QUOTES.has_key?(c)
            if c == @string_quote
              escaped_s << escaped_char
            else
              escaped_s << c
            end
          else
              escaped_s << escaped_char
          end
        else
          escaped_s << c
        end
      }

      return escaped_s
    end
    
  end
end
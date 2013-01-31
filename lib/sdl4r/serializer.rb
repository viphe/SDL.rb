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

  require 'ostruct'
	require 'forwardable'
  
  require 'sdl4r/serialization'
  require 'sdl4r/abstract_writer'
  require 'sdl4r/nil_writer'

  # Allows to serialize/deserialize between SDL and Ruby objects.
  #
  # Classes which need to implement custom serialization/deserialization should define the
  # +to_sdl()+ and +from_sdl()+ methods as follows:
  #
  #   class MyClass
  #
  #     attr_accessor :firstname
  #
  #     def from_sdl(tag, serializer = Serializer.new)
  #       self.firstname = tag.attribute("name")
  #       self
  #     end
  #
  #     def to_sdl(serializer = Serializer.new)
  #       serializer.start_tag("name")
  #       serializer.writer.value(self.firstname)
  #       serializer.end_tag
  #     end
  #
  #   end
  #
  # Custom serialization (using +to_sdl()+) or deserialization (using +from_sdl()+) can be more
  # efficient than the standard one as its logic is more straightforward).
  #
  # == Author
  # Philippe Vosges
  #
  class Serializer
    extend Forwardable
    include Serialization, AbstractWriter

    @@DEFAULT_OPTIONS = {
      :omit_nil_properties => false,
      :default_namespace => ""
    }
    
    attr_reader :options
    attr_reader :writer

		def_delegators :@writer, :start_body, :end_body, :value, :attribute

    #
    # _writer_:: underlying output writer (defaults to a Writer+StringIO)
    #
    # === options:
    #
    #  [:omit_nil_properties]
    #  if true, nil object properties are not exported to the serialized SDL (default: false)
    #  [:default_namespace]
    #  the default namespace of the generated tags (default: ""). This namespace doesn't apply to
    #  attributes.
    #
    def initialize(writer = nil, options = nil)
      writer, options = nil, writer if writer.kind_of? Hash and options.nil?
      writer ||= Writer.new
      options ||= {}

      raise ArgumentError, "writer should be a SDL4R::AbstractWriter" \
        unless writer.kind_of? SDL4R::AbstractWriter

			super()
      
      @writer = writer
      @options = {}.merge(@@DEFAULT_OPTIONS).merge!(options)
      @depth = 0
    end

    # Writes the start of a new Tag (representing 'o').
    # 
    # _name_:: name of the Tag to create (can be +nil+ for a root Tag)
    #
    def start_element(namespace, name = nil, &block)
			namespace, name = @options[:default_namespace], namespace unless name

      @writer.start_element(namespace, name)
			if block_given?
				block[self]
				end_element
			else
				@depth += 1
			end
    end

    # Ends the currently written Tag.    
    def end_element
      @writer.end_element
      @depth -= 1
    end

    # Serializes the given object into the underlying writer.
    #
    def write_object(o)
			# do a blank run with a NilWriter in order to count object appearances
			normal_writer = @writer
			begin
				@writer = NilWriter.new
				start_recording
				serialize_impl(o)
			ensure
				stop_recording
				@writer = normal_writer
			end

      serialize_impl(o)

      nil
    end

		def serialize(o)
			write_object(o)
		end

    # Serializes 'o' into the underlying writer.
    # Dislike #serialize this method doesn't perform any final operation like assigning object ids
    # attributes to the Tags that represent serialized objects.
    #
    # _use_new_tag_ ::
    #   if true (default) 'o' is serialized in a new tag, otherwise the current one (in the writer)
    #   is used
    #
    def serialize_impl(o)
      # insert object ids/refs
			ref = reference_object(o)
			if ref.multi_ref?
				if ref.count == 1
          if @depth == 0
            # repetition of the root object in the graph
            start_tag OBJECT_ID_ATTR_NAME
            @writer.value ref.oid
            end_tag
          else
					  @writer.attribute('', OBJECT_ID_ATTR_NAME, ref.oid)
          end
				else
					@writer.attribute('', OBJECT_REF_ATTR_NAME, ref.oid)
          return # make sure we don't loop in the graph
				end
      end

      # object data serialization
      if o.respond_to? :to_sdl
        o.to_sdl(self)

      else
        case o
        when OpenStruct
          serialize_hash(o.marshal_dump)
        when Hash
          serialize_hash(o)
        else
          serialize_plain_object(o)
        end
      end
    end

    private :serialize_impl

    def serialize_hash(hash)
      hash.each_pair { |key, value|
        serialize_property(key.to_s, value)
      }
    end

    def serialize_plain_object(o)
      processed_properties = {}

      # Read+write attributes are used rather than variables
      o.methods.each { |name|
        if name =~ /\w/ and # check this is not an operator
            name =~ /^([^=]+)=$/ # check setter name pattern
          if get_method(o, name, 1)
            getter_name = $1
            getter = get_method(o, getter_name, 0)

            if getter
              # read and write accessors are defined
              value = getter.call
              serialize_property(getter_name, value)
              processed_properties[getter_name] = true
            end
          end
        end
      }

      # Otherwise, we read instance variables
      o.instance_variables.each { |variable_name|
        name = variable_name[1..variable_name.size] if variable_name =~ /^@/
        unless processed_properties.has_key?(name)
          value = o.instance_variable_get(variable_name)
          serialize_property(name, value)
        end
      }
    end

    # Serializes a property.
    # Ignores any property whose name is not a valid SDL name.
    #
    # _name_:: property name
    # _value_:: property value (SDL value, plain object or Array)
    #
    def serialize_property(name, value)
      return unless SDL4R::valid_identifier?(name)

      if value.is_a? Array
        serialize_array(name, value)

      elsif SDL4R::is_coercible?(value)
        # SDL literal type
        unless value.nil? and @options[:omit_nil_properties]
          if @depth == 0 # at root level we use tags with single values rather than attributes
            start_tag(name)
            @writer.value(value)
            end_tag
          else
            @writer.attribute('', name, value)
          end
        end

      else
        serialize_as_tag(name, value)
      end
    end

    def serialize_array(name, array)
      not_literal_values = array.reject { |item| SDL4R::is_coercible?(item) }
      if not_literal_values.empty? and @depth > 0
        # If it is an array of SDL-compatible values, we use SDL values.
        start_tag(name)
        @writer.values(array)
        end_tag

      else
        # Otherwise, we use separate child tags.
        serialize_array_as_child_tags(name, array)
      end
    end

    def serialize_array_as_child_tags(name, array)
      array.each { |item|
        if SDL4R::is_coercible?(item)
          start_tag(name)
          @writer.value(item)
          end_tag
        else
          serialize_as_tag(name, item)
        end
      }
    end

    # Serializes an object as a new tag.
    #
    # _name_:: name used for the object
    #
    def serialize_as_tag(name, value)
      start_tag(name)
      serialize_impl(value)
      end_tag
    end
  end
end

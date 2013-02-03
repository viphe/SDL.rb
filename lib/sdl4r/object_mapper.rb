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
  
  # Support object for serialization-related classes.
  #
  class ObjectMapper

    OBJECT_ID_ATTR_NAME = 'oid'
    OBJECT_REF_ATTR_NAME = 'oref'

    DEFAULT_OPTIONS = {
        :omit_nil_properties => false,
        :default_element_namespace => '',
        :default_attribute_namespace => ''
    }.freeze

    def initialize(options = nil)
      @next_oid = 1
      @ref_by_oid = {}
      @ref_by_object = {}
      @recording = false

      @options = options ? DEFAULT_OPTIONS.merge(options) : DEFAULT_OPTIONS.clone
      @options.freeze
    end

    attr_reader :options

    def element_namespace
      @options[:default_element_namespace]
    end

    def attribute_namespace
      @options[:default_attribute_namespace]
    end

    def omit_nil_properties?
      @options[:omit_nil_properties]
    end

    def oid_attr
      OBJECT_ID_ATTR_NAME
    end

    def oref_attr
      OBJECT_REF_ATTR_NAME
    end

    # Indicates whether a given object should be considered as a collection (Enumerable at a minimum).
    # By default, any Enumerable, which is not a Hash is considered a collection.
    def collection?(object)
      object.is_a? Enumerable and not object.is_a? Hash
    end

    # Iterates over each SDL-compatible property of the given object and calls the given block.
    #
    # @yield [namespace, name, value, type]
    # @yieldparam namespace [String] namespace of the property
    # @yieldparam name [String] name of the property
    # @yieldparam value value of the property
    # @yieldparam type [Symbol] :element for a child element, :attribute for an attribute
    #
    def each_property(object, &block)
      case object
        when OpenStruct
          each_hash_property(object.marshal_dump, &block)
        when Hash
          each_hash_property(object, &block)
        else
          each_plain_object_property(object, &block)
      end
    end

    def each_hash_property(hash, &block)
      hash.each_pair { |key, value|
        each_property_impl(key, value, &block)
      }
    end
    private :each_hash_property

    # Calls the given block for the given property, either classifying it as an attribute or a child element.
    # Ignores the property if its name is not a valid SDL name.
    #
    # @param name [String] property name (converted into a String using Object#to_s)
    # @param value property value (SDL-coercible values will be considered as attributes, by default)
    #
    def each_property_impl(name, value, &block)
      name = name.to_s
      return false unless SDL4R::valid_identifier?(name)

      if collection?(value)
        each_collection_property_impl(name, value, &block)

      elsif SDL4R::is_coercible?(value)
        # SDL literal type
        unless value.nil? and omit_nil_properties?
          block.call(attribute_namespace, name, value, :attribute)
        end

      else
        block.call(element_namespace, name, value, :element)
      end
    end
    private :each_property_impl

    # @param name [String]
    # @param collection [Enumerable]
    def each_collection_property_impl(name, collection, &block)
        block.call(element_namespace, name, collection, :element)
    end
    private :each_collection_property_impl

    def each_plain_object_property(o, &block)
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
              each_property_impl(getter_name, value, &block)
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
          each_property_impl(name, value, &block)
        end
      }
    end
    private :each_plain_object_property

    # Writes a reference to an Object already encountered in the stream.
    # This method is a support for handling cycles in object graphs.
    #
    # @param name tag name
    # @param oid the identifier of the object
    # @param object_mapper support for serialization
    #
    def write_object_ref(writer, name, oid)
      writer.start_element name
      writer.attribute(oref_attr, oid)
      writer.end_element
    end

    def start_recording
      @recording = true
    end

    def stop_recording
      @recording = false
      @ref_by_oid.each_value do |ref|
        ref.record
      end
    end
    
    # Resets the cache of object references/ids and the underlying IO if writing.
    def flush
      @ref_by_oid.clear
      @ref_by_object.clear
    end

    # Represents a reference to an object during serialization or deserialization.
    # Used in order to avoid infinite cycles, repetitions, etc.
    #
    class Ref
      attr_reader :object, :count, :recorded_count
      attr_accessor :oid, :tag_name

      # Initializes a reference with a reference counter of 0.
      #
      def initialize(object_mapper, object, oid)
        @object_mapper = object_mapper
        @tag_name = nil
        @object = object
        @oid = oid
        @count = 0
        @recorded_count = nil
      end

      # Increments the reference counter by one.
      #
      def inc
        @count += 1
      end

      def record
        @recorded_count = @count
        @count = 0
      end

      def multi_ref?
        if @recorded_count
          @recorded_count > 1
        else
          true # by default
        end
      end

      # Writes a Tag representing this Ref with the specified writer.
      #
      # _name_:: name of the created Tag (if +nil+, the definition Tag name - i.e. the name of the
      #   first Tag representing the referenced object - is used)
      #
      def write_object_ref(writer, name)
        name ||= tag_name
        @object_mapper.write_object_ref(writer, name, @oid)
      end

    end

    # References the provided object if it is not already referenced. If the object is referenced
    # already, returns the corresponding Ref. The reference counter is not incremented by this
    # method.
    #
    # _oid_:: the Object ID (ignore if serializing, provide if deserializing).
    #
    def reference_object(object, oid = nil)
      ref = get_object_ref(object)

      unless ref
        unless oid
          oid = @next_oid
          @next_oid += 1
        end
        
        ref = Ref.new(self, object, oid)
        @ref_by_oid[oid] = @ref_by_object[object.object_id] = ref
      end

      ref.inc
      ref
    end

    # Returns the Ref corresponding to the specified object or nil if not found.
    #
    def get_object_ref(object)
      @ref_by_object[object.object_id]
    end

    # Indicates whether the specified property is a serializable property for the given object.
    #
    def serializable_property?(object, property_name)
      object.is_a?(OpenStruct) ||
        object.is_a?(Hash) ||
        object.instance_variable_defined?("@#{property_name}") ||
        (get_method(object, property_name, 0) and get_method(object, "#{property_name}=", 1))
    end

    # Returns the method of object 'o', which has the specified name and arity (with or without
    # default parameters). Returns nil if no such method corresponds.
    #
    def get_method(object, method_name, arity)
      begin
        m = object.method(method_name)
      rescue NameError
        m = nil
      end

      unless m.nil? or m.arity == arity or m.arity == (-arity - 1)
        m = nil
      end

      m
    end
    
  end
end

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
  #     def to_sdl(serializer = Serializer.new, tag = serializer.new_tag(nil, self, nil))
  #       tag.set_attribute("name", self.firstname)
  #       tag
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

    OBJECT_ID_ATTR_NAME = 'oid'
    OBJECT_REF_ATTR_NAME = 'oref'

    @@DEFAULT_OPTIONS = {
      :omit_nil_properties => false,
      :default_namespace => ""
    }

    #
    #
    # === options:
    #
    #  [:omit_nil_properties]
    #  if true, nil object properties are not exported to the serialized SDL (default: false)
    #  [:default_namespace]
    #  the default namespace of the generated tags (default: ""). This namespace doesn't apply to
    #  attributes.
    #
    def initialize(options = {})
      @options = {}.merge(@@DEFAULT_OPTIONS).merge!(options)
      @next_oid = 1
      @ref_by_oid = {}
      @ref_by_object = {}
    end

    # Represents a reference to an object during serialization or deserialization.
    # Used in order to avoid infinite cycles, repetitions, etc.
    #
    class Ref
      attr_reader :o, :oid, :count
      attr_accessor :tag

      # Initializes a reference with a reference counter of 0.
      #
      def initialize(o, oid)
        @tag = nil
        @o = o
        @oid = oid
        @count = 0
      end

      # Increments the reference counter by one.
      #
      def inc
        @count += 1
      end
    end

    # References the provided object if it is not already referenced. If the object is referenced
    # already, returns the corresponding Ref. The reference counter is not incremented by this
    # method.
    #
    # _oid_:: the Object ID (ignore if serializing, provide if deserializing).
    #
    def reference_object(o, oid = nil)
      ref = @ref_by_object[o]

      unless ref
        unless oid
          oid = @next_oid
          @next_oid += 1
        end
        
        ref = Ref.new(o, oid)
        @ref_by_oid[oid] = @ref_by_object[o] = ref
      end

      ref
    end

    # Returns a new Tag to be used for serializing 'o'.
    # 
    # _name_:: name of the Tag to create (can be +nil+ for a root Tag)
    #  _o_:: object/value that the new tag will represent
    # _parent_tag_:: parent Tag of the new tag
    #
    def new_tag(name, o, parent_tag = nil)
      if name
        namespace = @options[:default_namespace]
      else
        namespace = ''
        name = SDL4R::ROOT_TAG_NAME
      end

      if parent_tag.nil?
        Tag.new(namespace, name)
      else
        parent_tag.new_child(namespace, name)
      end
    end

    # Returns a Tag representing the provided Ref.
    #
    # _name_:: name of the created Tag (if +nil+, the definition Tag name - i.e. the name of the
    #   first Tag representing the referenced object - is used)
    # _ref_:: represented reference (Ref)
    # _parent_tag_:: parent Tag of the created Tag
    #
    def new_ref_tag(name, ref, parent_tag)
      name = ref.tag.name if name.nil?

      ref_tag = parent_tag.new_child(@options[:default_namespace], name)
      ref_tag.set_attribute('', OBJECT_REF_ATTR_NAME, ref.oid)
      ref_tag
    end

    # Serializes the given object into a returned Tag.
    #
    # _tag_:: a Tag representing 'o' (if not provided, one will be created).
    #
    def serialize(o, tag = nil, parent_tag = nil)
      root = serialize_impl(o, tag, parent_tag)

      # Assign an OID attribute to tags of objects referenced more than once
      @ref_by_object.each_value { |ref|
        if ref.count > 1
          ref.tag.set_attribute('', OBJECT_ID_ATTR_NAME, ref.oid)
        end
      }

      root
    end

    # Serializes 'o' into a Tag, which is then returned.
    # Dislike #serialize this method doesn't perform any final operation like assigning object ids
    # attributes to the Tags that represent serialized objects.
    #
    # _tag_:: a tag to be used as the serialized form of 'o'.
    #   Note that this parameter will be ignored if the +to_sdl()+ is called on the serialized
    #   object.
    #
    def serialize_impl(o, tag = nil, parent_tag = nil)
      tag = new_tag(nil, o, parent_tag) if tag.nil?
      raise ArgumentError, '"tag" must be a Tag' unless tag.is_a?(Tag)

      if o.respond_to? :to_sdl
        tag = o.to_sdl(self, tag)

      else
        tag = case o
        when OpenStruct
          serialize_hash(o.marshal_dump, tag)

        when Hash
          serialize_hash(o, tag)

        else
          serialize_plain_object(o, tag)
        end
      end

      tag
    end

    private :serialize_impl

    def serialize_hash(hash, tag)
      hash.each_pair { |key, value|
        serialize_property(key.to_s, value, tag)
      }
      tag
    end

    def serialize_plain_object(o, tag)
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
              serialize_property(getter_name, value, tag)
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
          serialize_property(name, value, tag)
        end
      }

      tag
    end

    # Returns the method of object 'o', which has the specified name and arity (with or without
    # default parameters). Returns nil if no such method corresponds.
    #
    def get_method(o, method_name, arity)
      begin
        m = o.method(method_name)
      rescue NameError
        m = nil
      end

      unless m.nil? or m.arity == arity or m.arity == (-arity - 1)
        m = nil
      end

      return m
    end

    # Indicates whether the specified property is a serializable property for the given object.
    #
    def serializable_property?(o, property_name)
      return o.is_a?(OpenStruct) ||
        o.is_a?(Hash) ||
        o.instance_variable_defined?("@#{property_name}") ||
        (get_method(o, property_name, 0) and get_method(o, "#{property_name}=", 1))
    end

    # Serializes a property under a given Tag.
    # Ignores any property whose name is not a valid SDL name.
    #
    # _name_:: property name
    # _value_:: property value (SDL value, plain object or Array)
    #
    def serialize_property(name, value, parent_tag)
      return unless SDL4R::valid_identifier?(name)

      if value.is_a? Array
        serialize_array(name, value, parent_tag)

      elsif SDL4R::is_coercible?(value)
        # SDL literal type
        unless value.nil? and @options[:omit_nil_properties]
          if parent_tag.name == SDL4R::ROOT_TAG_NAME
            value_tag = new_tag(name, value, parent_tag)
            value_tag.values = [value]
          else
            parent_tag.set_attribute(name, value)
          end
        end

      else
        serialize_object_or_ref(name, value, parent_tag)
      end
    end

    def serialize_array(name, array, parent_tag)
      not_literal_values = array.reject { |item| SDL4R::is_coercible?(item) }
      if not_literal_values.empty?
        # If it is an array of SDL-compatible values, we use SDL values.
        array_tag = new_tag(name, array, parent_tag)
        array_tag.values = array

      else
        # Otherwise, we use separate child tags.
        serialize_array_as_child_tags(name, array, parent_tag)
      end
    end

    def serialize_array_as_child_tags(name, array, parent_tag)
      array.each { |item|
        if SDL4R::is_coercible?(item)
          value_tag = new_tag(name, item, parent_tag)
          value_tag.values = [item]
        else
          serialize_object_or_ref(name, item, parent_tag)
        end
      }
    end

    # Serializes an object (possibly using a reference).
    #
    # _name_:: name used for the object in the parent Tag
    #
    def serialize_object_or_ref(name, value, parent_tag)
      ref = reference_object(value)
      ref.inc
      
      if ref.count == 1
        ref.tag = new_tag(name, value, parent_tag)
        serialize_impl(value, ref.tag)
      else
        new_ref_tag(name, ref, parent_tag)
      end
    end

    public

    # Provides deserialized new plain object instances (i.e. "plain object" as opposed to special
    # cases like SDL values).
    # By default, returns 'o' or a new instance of OpenStruct if 'o' is +nil+.
    #
    # _tag_:: the deserialized Tag
    # _o_:: the currently used object or nil if there is none yet
    # _parent_object_:: the parent object or +nil+ if root
    #
    def new_plain_object(tag, o = nil, parent_object = nil)
      if o.nil?
        OpenStruct.new
      else
        o
      end
    end

    def deserialize(tag, o = new_plain_object(tag))
      if o.respond_to? :from_sdl
        o = o.from_sdl(tag, self)
        
      else
        o = deserialize_object(tag, o)
      end

      o
    end

    # Called by #deserialize when not using +from_sdl()+.
    # Deserializes the specified tag into an object using values, attributes, child tags, etc.
    #
    def deserialize_object(tag, o = new_plain_object(tag))
      deserialize_from_child_tags(tag, o, true)
      deserialize_from_values(tag, o)
      deserialize_from_attributes(tag, o)
      deserialize_from_child_tags(tag, o, false)

      o = apply_anonymous_tag_list_idiom(tag, o)
      
      o
    end

    def deserialize_from_values(tag, o)
      if tag.has_values?
        if tag.has_children? or tag.has_attributes?
          property_value = tag.values

          if o.instance_variable_defined?("@value") or not o.instance_variable_defined?("@values")
            # value is preferred
            property_name = "value"
            property_value = property_value[0] if property_value.length == 1
          else
            property_name = "values"
          end

          if serializable_property?(o, property_name)
            set_serializable_property(o, property_name, property_value)
          end

        else
          # the tag only has values
          return property_value.length == 1 ? property_value[0] : property_value
        end
      end
    end

    def deserialize_from_attributes(tag, o)
      tag.attributes do |attribute_namespace, attribute_name, attribute_value|
        if attribute_namespace == '' and attribute_name == OBJECT_REF_ATTR_NAME
          # ignore this technical attribute

        elsif attribute_namespace == '' and attribute_name == OBJECT_ID_ATTR_NAME
          # reference and make no impact on 'o'
          ref = reference_object(o, attribute_value)
          ref.inc

        else
          set_serializable_property(o, attribute_name, attribute_value)
        end
      end
    end

    # Returns the name of the property to which the specified Tag is supposed to be assigned in the
    # parent object.
    # Default behavior: this implementation returns the tag's name (ignoring the namespace).
    #
    def get_deserialized_property_name(tag, parent_tag, parent_object)
      tag.name
    end

    # _handle_anonymous_::
    #   if true, this method only handles anonymous child tags,
    #   if false, it only handles named child tags
    #
    def deserialize_from_child_tags(tag, o, handle_anonymous)
      # Group the homonym tags together
      child_tags_by_name = {}
      tag.children do |child|
        if handle_anonymous == (child.namespace == '' and child.name == SDL4R::ANONYMOUS_TAG_NAME)
          property_name = get_deserialized_property_name(child, tag, o)
          homonymous_children = (child_tags_by_name[property_name] ||= [])
          homonymous_children << child
        end
      end

      child_tags_by_name.each_pair do |property_name, homonymous_children|
        # Check wether this variable is assignable
        if o.is_a? Array or serializable_property?(o, property_name)
          property_values = []

          homonymous_children.each do |child|
            property_value = nil

            if child.has_attribute?(OBJECT_REF_ATTR_NAME)
              # Object reference
              ref = @ref_by_oid[child.attribute(OBJECT_REF_ATTR_NAME)]
              property_value = deserialize(child, ref.o) if ref

            elsif child.has_values? and not child.has_children? and not child.has_attributes?
              # If the object only has values (no children, no atttributes):
              #  then the values are the variable value
              property_value = child.values
              property_value = property_value[0] if property_value.length == 1

            else
              # Consider this tag as a plain object
              variable_name = "@#{property_name}"
              previous_value =
                (o.instance_variable_defined? variable_name) ?
                  o.instance_variable_get(variable_name) :
                  nil
              if previous_value.nil? or SDL4R::is_coercible?(previous_value)
                property_value = deserialize(child, new_plain_object(child, nil, o))
              else
                property_value = deserialize(child, new_plain_object(child, previous_value, o))
              end
            end

            property_values << property_value
          end

          if o.is_a? Array
            o.concat(property_values)
          elsif property_values.length == 1
            set_serializable_property(o, property_name, property_values[0])
          elsif property_values.length > 1
            set_serializable_property(o, property_name, property_values)
          end
        end
      end
    end

    private

    def apply_anonymous_tag_list_idiom(tag, o)
      if tag.has_child?('', SDL4R::ANONYMOUS_TAG_NAME) and
          not tag.has_attributes? and not tag.has_values?

        getter = get_method(o, SDL4R::ANONYMOUS_TAG_NAME, 0)
        if getter
          # Check that the tag only has anonymous tags
          anonymous_child_tags = nil
          tag.children do |child|
            if child.namespace == '' and child.name == SDL4R::ANONYMOUS_TAG_NAME
              anonymous_child_tags ||= []
              anonymous_child_tags << child
            else
              anonymous_child_tags = nil
              break
            end
          end

          if anonymous_child_tags and tag.child_count == anonymous_child_tags.length
            # Only anonymous child tags were found.
            value = getter.call
            return value
          end
        end
      end

      return o
    end

    public

    # Sets the given property in the given object.
    # Returns whether the property has been assigned or not.
    #
    # This method could be redefined in order to convert a value to a custom one, for instance.
    #
    def set_serializable_property(o, name, value)
      case o
      when Hash
        o[name] = value
        return true

      when OpenStruct
        o.send "#{name}=", value
        return true

      else
        accessor_name = "#{name}="
        if o.respond_to?(accessor_name)
          o.send accessor_name, value
          return true

        else
          variable_name = "@#{name}"
          if o.instance_variable_defined?(variable_name)
            o.instance_variable_set(variable_name, value)
            return true
            
          else
            return false
          end
        end
      end
    end
  end
end

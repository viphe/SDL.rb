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
  
  require 'sdl4r/object_mapper'
  
  # Deserializes between SDL and Ruby objects.
  #
  # Classes which need to implement custom deserialization should define the
  # +from_sdl()+ methods as follows:
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
  #   end
  #
  # Custom serialization (using +to_sdl()+) or deserialization (using +from_sdl()+) can be more
  # efficient than the standard one as its logic is more straightforward).
  #
  # == Author
  # Philippe Vosges
  #
  class Deserializer
    include Serialization

    @@DEFAULT_OPTIONS = {
    }

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
          homonym_children = (child_tags_by_name[property_name] ||= [])
          homonym_children << child
        end
      end

      child_tags_by_name.each_pair do |property_name, homonym_children|
        # Check whether this variable is assignable
        if o.is_a? Array or serializable_property?(o, property_name)
          property_values = []

          homonym_children.each do |child|
            property_value = nil

            if child.has_attribute?(OBJECT_REF_ATTR_NAME)
              # Object reference
              ref = @ref_by_oid[child.attribute(OBJECT_REF_ATTR_NAME)]
              property_value = deserialize(child, ref.o) if ref

            elsif child.has_values? and not child.has_children? and not child.has_attributes?
              # If the object only has values (no children, no attributes):
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
    # @return whether the property has been assigned or not.
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

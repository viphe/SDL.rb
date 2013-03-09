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
  
  # Abstract writer of a SDL stream.
  #
  # @abstract
  #
  module AbstractWriter

    attr_accessor :object_mapper


    # @return [Integer] 0 at the root level and a higher int otherwise.
    # @abstract
    def depth
      raise 'abstract method'
    end

    # Writes the declaration of a tag.
    # No validity check as for legal characters is performed on +name+ and +namespace+.
    #
    # @abstract
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
      raise 'abstract method'
    end

    # (see #start_element)
    def start_tag(namespace, name = nil)
      start_element(namespace, name)
    end
    
    # Ends the current tag, closing its body if necessary.
    #
    # @abstract
    def end_element
      raise 'abstract method'
    end

    # (see #end_element)
    def end_tag
      end_element
    end

    # Writes the start of a tag body to the underlying IO.
    # @return [self]
    #
    # @abstract
    def start_body
      raise 'abstract method'
    end
    
    # Writes the end of a tag body to the underlying stream.
    # @return [self]
    #
    # @abstract
    def end_body
      raise 'abstract method'
    end
    
    # Writes a tag. The tag is closed when the method exits.
    # 
    # @overload element(name)
    #   @param [String, Symbol] name
    #   
    # @overload element(namespace, name)
    #   @param [String, Symbol] name
    #   @param [String, Symbol] namespace
    #   
    # @yield closes the tag automatically at the end of the tag body.
    #
    def element(n1, n2 = nil)
      start_element n1, n2
      begin
        yield if block_given?
      ensure
        end_element
      end
      self
    end

    # (see #element)
    def tag(n1, n2 = nil, &block)
      element n1, n2, &block
    end
    
    # Writes one value or several.
    #
    # @abstract
    # 
    # @return [self]
    #
    def value(*values)
      raise 'abstract method'
    end

    # (see #value)
    def values(*values)
      value(*values)
    end
    
    # Used to discriminate an unprovided parameter from +nil+.
    # @private
    MISSING_PARAMETER = Object.new # :nodoc:
    
    # Writes the specified attribute.
    #
    # @abstract
    #
    # @overload child(name)
    #   @param [String, Symbol] name
    #   @param [Object] value attribute value
    #   
    # @overload child(namespace, name)
    #   @param [String, Symbol] name
    #   @param [String, Symbol] namespace
    #   @param [Object] value attribute value
    # 
    # @return [self]
    # 
    def attribute(namespace, name, value = MISSING_PARAMETER)
      raise 'abstract method'
    end
    
    # Writes the given objects to the underlying stream.
    #
    # @overload write(*objects)
    #   @param [Tag, Object] objects
    #       Objects to serialize as anonymous sub-elements or
    #       Tags to write under their own names.
    #       Nameless Objects are serialized directly into the current element, while Tags are always written as
    #       sub-elements.
    # @overload write(name, *objects)
    #   @param [String, Symbol] name name of the sub-elements
    #   @param [Tag, Object] objects objects to serialize as sub-elements (their names or namespaces are ignored)
    # @overload write(name, *objects)
    #   @param [String, Symbol] namespace namespace of the sub-elements
    #   @param [String, Symbol] name name of the sub-elements
    #   @param [Tag, Object] objects objects to serialize as sub-elements (their names or namespaces are ignored)
    #
    def write(*args)
      return if args.empty?

      # determine if name/namespace were provided
      first = args[0]
      if first.is_a? String or first.is_a? Symbol
        second = args[1]
        name_specified = true
        if second.is_a? String or second.is_a? Symbol
          namespace = first.to_s
          name = second.to_s
          args.slice!(0, 2)
        else
          namespace = ''
          name = first.to_s
          args.delete_at(0)
        end
      else
        name_specified = false
        namespace = nil
        name = nil
      end

      args.each do |o|
        unless name_specified
          if depth > 0 and (o.is_a? Tag or o.is_a? Element)
            namespace = o.namespace
            name = o.name
          else
            namespace = nil
            name = nil
          end
        end

        @object_mapper.record(namespace, name, o) unless o.is_a? Tag
        write_impl(namespace, name, o)
      end
      
      self
    end

    # Called by #write for each object to write.
    #
    # @param [String] namespace namespace of +o+ or +nil+ if +name+ is +nil+ (see below)
    # @param [String] name
    #   name of the element to contain +o+ or +nil+ if +o+ is to be written directly at the current
    #   level
    # 
    # @return +self+
    #
    def write_impl(namespace, name, o)
      if @object_mapper.collection?(o)
        write_collection_impl(namespace, name, o)

      else
        start_element(namespace, name) if name
        begin
          if o.is_a? Tag
            write_tag o
          else
            write_object(o, namespace == '' && name == SDL4R::ANONYMOUS_TAG_NAME)
          end

        ensure
          end_element if name
        end
      end

      self
    end
    protected :write_impl
    
    # Writes the contents of the specified Tag into this SDL stream.
    # The default implementation translates the Tag tree into lower-level calls.
    #
    # @param [Tag] tag the tag to write
    #
    # @return self
    #
    def write_tag(tag)
      is_root = (depth <= 0)
      values(*tag.values) unless is_root # otherwise ignored

      # Attributes are written in lexicographic order.
      if tag.has_attributes?
        all_attributes_hash = tag.attributes
        all_attributes_array = all_attributes_hash.sort { |a, b|
          namespace1, name1 = a[0].split(':')
          namespace1, name1 = '', namespace1 if name1.nil?
          namespace2, name2 = b[0].split(':')
          namespace2, name2 = '', namespace2 if name2.nil?

          diff = namespace1 <=> namespace2
          diff == 0 ? name1 <=> name2 : diff
        }

        omit_nil_properties = @object_mapper.omit_nil_properties?

        all_attributes_array.each do |attribute_name, attribute_value|
          next if attribute_value.nil? and omit_nil_properties

          if is_root
            element(@object_mapper.element_namespace, attribute_name) { value(attribute_value) }
          else
            attribute(attribute_name, attribute_value)
          end
        end
      end

      tag.children do |child|
        element child.namespace, child.name do
          write_tag child
        end
      end

      self
    end
    protected :write_tag
    
    # Writes a given object as a named sub-element of the current one.
    # Called by #write for anything that is not a Tag or an Element.
		#
		# @return self
    #
    def write_object(object, attributes_as_elements = false)
      if SDL4R::is_coercible?(object)
        value(object)

      else
        omit_nil_properties = @object_mapper.omit_nil_properties?

        @object_mapper.each_property(object) do |prop_namespace, prop_name, val, type|
          next if val.nil? and omit_nil_properties

          if depth <= 0
            case type
              when :attribute
                type = :element # at root level, attributes are turned into elements
              when :value # emit value into anonymous tags at root level
                element '', SDL4R::ANONYMOUS_TAG_NAME do
                  value val
                end
                next
              else
                # nothing special otherwise
            end
          end

          type = :element if attributes_as_elements and type == :attribute

          case type
            when :element
              write_impl(prop_namespace, prop_name, val)
            when :attribute
              attribute(prop_namespace, prop_name, val)
            when :value
              if val.is_a? Array
                value(*val)
              else
                value(val)
              end
            else
              # ignore
          end
        end
      end

      self
    end
    protected :write_object

    # Writes the given collection inside the current element.
    #
    # @param [Enumerable] collection the collection to write
    def write_collection_impl(namespace, name, collection)
      is_root = depth <= 0
      is_value_collection = collection.all? { |item| SDL4R::is_coercible?(item) }

      if is_value_collection
        if is_root
          # values are not supported at root level directly: wrap them in an anonymous tag
          element '', SDL4R::ANONYMOUS_TAG_NAME do
            write_collection_as_values(collection)
          end

        else
          start_element namespace, name if name
          write_collection_as_values(collection)
          end_element if name
        end

      else
        collection.each { |item|
          write_impl(namespace, name, item)
        }
      end
    end
    private :write_collection_impl

    def write_collection_as_values(collection)
      if collection.is_a? Array
        values(*collection)
      else
        collection.each { |item| value(item) }
      end
    end
    private :write_collection_as_values

    # Flushes any underlying IO or buffer needing flushing.
    # Don't forget to call this when overwriting.
    def flush
      @object_mapper.flush
    end
  end
end

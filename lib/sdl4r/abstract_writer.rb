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
      raise "not implemented"
    end

    # (see #start_element)
    def start_tag(namespace, name = nil)
      start_element(namespace, name)
    end
    
    # Ends the current tag, closing its body if necessary.
    #
    # @abstract
    def end_element
      raise "not implemented"
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
      raise "not implemented"
    end
    
    # Writes the end of a tag body to the underlying stream.
    # @return [self]
    #
    # @abstract
    def end_body
      raise "not implemented"
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
      yield if block_given?
      end_element
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
      raise "not implemented"
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
      raise "not implemented"
    end
    
    # Writes the given objects to the underlying stream.
    # @param [Object, Tag] o1, o2, ... Tags or objects to serialize
    def write(*args)
      args.each do |o|
        if o.is_a? Tag
          write_tag o
        else
          write_object o
        end
      end
      
      self
    end
    
    # Writes the specified Tag.
    def write_tag(tag)
      element(tag.namespace, tag.name) do
        values(*tag.values)
        
        # Attributes are written in lexicographic order.
        if tag.has_attributes?
          all_attributes_hash = tag.attributes
          all_attributes_array = all_attributes_hash.sort { |a, b|
            namespace1, name1 = a[0].split(':')
            namespace1, name1 = "", namespace1 if name1.nil?
            namespace2, name2 = b[0].split(':')
            namespace2, name2 = "", namespace2 if name2.nil?

            diff = namespace1 <=> namespace2
            diff == 0 ? name1 <=> name2 : diff
          }
          
          all_attributes_array.each do |attribute_name, attribute_value|
            attribute(attribute_name, attribute_value)
          end
        end
        
        tag.children do |child|
          write_tag(child)
        end
      end
      
      self
    end
    
    # Serializes the specified Object.
		#
		# @return self
    def write_object(o)
      @serializer ||= Serializer.new(self)
      @serializer.serialize(o)
      self
    end

    # Flushes any underlying IO or buffer needing flushing.
    # Don't forget to call this when overwriting.
    def flush
      @serializer.flush if @serializer
    end
  end
end

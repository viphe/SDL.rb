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
  
  # Base module for serialization-related classes.
  # 
  # @abstract
  #
  module Serialization

    OBJECT_ID_ATTR_NAME = 'oid'
    OBJECT_REF_ATTR_NAME = 'oref'
    
    def initialize
      @next_oid = 1
      @ref_by_oid = {}
      @ref_by_object = {}
			@recording = false
    end

    def oid_attr
      OBJECT_ID_ATTR_NAME
    end

    def oref_attr
      OBJECT_REF_ATTR_NAME
    end

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

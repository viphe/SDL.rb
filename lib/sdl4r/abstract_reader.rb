# INCLUDING MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program; if not, contact the Free Software Foundation, Inc.,
# 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
#++

module SDL4R

  require 'sdl4r/sdl4r'

  # Abstract reader of a SDL stream.
  #
  # @abstract
  #
  module AbstractReader

    TYPE_ELEMENT = :ELEMENT
    TYPE_END_ELEMENT = :END_ELEMENT


    # @attr [ObjectMapper] used during serialization operations
    attr_accessor :object_mapper


    # @abstract
    def rewindable?
      raise 'abstract method'
    end

    # Resets the position of this reader to the beginning of the SDL stream. Note that some readers are not rewindable.
    # @abstract
    def rewind
      raise 'abstract method'
    end

    # Type of the traversed SDL node (e.g. TYPE_ELEMENT).
    # @abstract
    def node_type
      raise 'abstract method'
    end

    # Prefix (namespace) of the traversed SDL node.
    # @abstract
    def prefix
      raise 'abstract method'
    end

    # Name of the traversed SDL node.
    # @abstract
    def name
      raise 'abstract method'
    end

    # Depth of the current SDL node. Depth of top nodes is 1 (0 would be the root that the Reader
    # doesn't traverse).
    # @abstract
    def depth
      raise 'abstract method'
    end

    # @return [Array] an array of the attributes of the traversed SDL node structured as follows:
    #   <code>[ ["ns1", "attr1", 123], ["", "attr2", true] ]</code>
    # @abstract
    def attributes
      raise 'abstract method'
    end

    # @return the value of the specified attribute.
    #
    # @overload attribute(name)
    # @overload attribute(prefix, name)
    # @abstract
    def attribute(prefix, name = nil)
      raise 'abstract method'
    end

    # @return the attribute at the specified index: <code>[namespace, name, value]</code>.
    # @abstract
    def attribute_at(index)
      raise 'abstract method'
    end

    # @return [Integer] number of attributes in the current element
    # @abstract
    def attribute_count
      raise 'abstract method'
    end

    # @return [boolean] whether the current element has attributes.
    # @abstract
    def attributes?
      raise 'abstract method'
    end

    # @return the values of the current node, nil if there are none.
    # @abstract
    def values
      raise 'abstract method'
    end

    # @return the first of the values or nil if there are none
    def value
      v = values
      v ? v.first : nil
    end

    def values?
      v = values
      v ? v.count > 0 : false
    end

    # Indicates whether the current element is self-closing i.e. has no content. Depending on the reader an element
    # might have no sub-elements and still not be self-closing. Possible example with SDL markup:
    #
    #  self_closing 123
    #  not_self_closing name="empty block" {}
    #
    # @abstract
    def self_closing?
      raise 'abstract_method'
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
    # @return [AbstractReader]  +self+ if a new node has been reached
    #                           or +nil+ if the end of file has been reached.
    # @abstract
    def read
      raise 'abstract method'
    end

    # Enumerates all the parsed nodes and calls the given block.
    #
    # @yield [AbstractReader] the current node
    #
    # @example
    #   open("sample.sdl") do |io|
    #     SDL4R::Reader.from_io(io).each do |node]
    #       puts node.node_type
    #     end
    #   end
    #
    def each
      while node = self.read
        yield node
      end
    end

    # Creates and returns the object representing a datetime (calls SDL4R#new_time by default).
    # Derived classes are supposed to call this factory method in order to create time attribute values or time values.
    # Can be overwritten.
    #
    #   def new_time(year, month, day, hour, min, sec, msec, timezone_code)
    #     Time.utc(year, month, day, hour, min, sec, msec, timezone_code)
    #   end
    #
    def new_time(year, month, day, hour, min, sec, msec, timezone_code)
      SDL4R::new_time(year, month, day, hour, min, sec, msec, timezone_code)
    end

    # Calls the given block for each encountered Tag. The block is called when the Tag definition
    # is complete (i.e. at the end of the tag).
    #
    # @param [boolean] only_top_tags if true only top Tags are enumerated
    # @yield [Tag] called at each Tag
    #
    def each_tag(only_top_tags = false)
      stack = []
      tag = nil # Only used during definition (values + attributes)

      while node = read
        case node.node_type

          when TYPE_ELEMENT
            tag = Tag.new @element.prefix, @element.name
            node.attributes.each do |attr_ns, attr_name, attr_value|
              tag.set_attribute(attr_ns, attr_name, attr_value)
            end
            values = node.values
            tag.values = values if values
            stack.last.add_child(tag) unless stack.empty?

            if node.self_closing?
              yield tag if !only_top_tags or @depth <= 1
            else
              stack << tag
            end

            tag = nil # definition ended here

          when TYPE_END_ELEMENT
            tag = stack.pop
            yield tag if !only_top_tags or depth <= 1

          else
        end
      end
    end
    
    def new_plain_object
      object_mapper.new_plain_object(self)
    end

    # Calls #load.
    def from_sdl(o = nil)
      load(o)
    end

    # Turns the element currently traversed by this AbstractReader into an object representation.
    #
    # @return [Object] the 
    #
    def load(o = nil)
      return o.from_sdl(self) if o and o.respond_to? :from_sdl # custom handling
      
      children = nil
      
      while read
        case node_type
        when TYPE_ELEMENT
        puts ">>> #{name} @ #{depth}"
          child = load
          if children
            children << [prefix, name, child]
          else
            children = [[prefix, name, child]]
          end
          
        when TYPE_END_ELEMENT
        puts "<<< #{name}"
          # only comes here when at the end of the element first reached in this call
          # (because of recursion)
          return construct_object(children)
          
        else
        end
      end
      
      raise "expected a TYPE_END_ELEMENT event (#{name}, depth=#{depth})" if depth >= 0 # should have returned above

      depth < 0 ? children.first[2] : children 
    end

    private
    
    def construct_object(children)
      if children.nil? and values? and not attributes?
        o = values.length > 1 ? values : values.first
      else
        o = object_mapper.create_object(self)
        assign_values(o)
        assign_attributes(o)
        o = assign_children(o, children) if children
      end
      
      o
    end

    # Assigns the values of the currently traversed element to the "value" or "values" property of
    # +o+.
    #
    def assign_values(o)
      if values?
        property_value = values

        if o.instance_variable_defined?('@value') or not o.instance_variable_defined?('@values')
          # value is preferred
          property_name = 'value'
          property_value = property_value[0] if property_value.length == 1
        else
          property_name = "values"
        end

        if object_mapper.property?(o, nil, property_name)
          object_mapper.set_property(o, nil, property_name, property_value)
        end
      end
    end

    # Assigns the attributes of the currently traversed element to properties of +o+.
    #
    def assign_attributes(o)
      attributes.each do |attribute_namespace, attribute_name, attribute_value|
        object_mapper.set_property(o, attribute_namespace, attribute_name, attribute_value)
      end
    end

    # Assigns children to properties of +o+ or applies the following idiom:
    # if +o+ is only composed of anonymous tags, it is turned into an Array containing only those
    # (concatenated).
    # 
    #   numbers {
    #     1 2 3 4
    #     5 6 7 8 
    #   }
    #
    # becomes (when combined with the idiom turning a tag with values only into an array of those)
    #
    #   p root.numbers # => [1, 2, 3, 4, 5, 6, 7, 8]
    #
    # @return +o+ or a replacement for +o+
    #
    def assign_children(o, children)
      # Group the homonymous tags together
      children_by_name = {}
      anonymous_count = 0
      children.each do |ns, name, child|
        homonymous_children = (children_by_name[[ns, name]] ||= [])
        homonymous_children << child
        anonymous_count += 1 if ns == '' and name == SDL4R::ANONYMOUS_TAG_NAME
      end
      
      if children.count == anonymous_count and not values? and not attributes?
        # turn o into an Array
        o = []
      end
      
      children_by_name.each_pair do |ns_name, homonymous_children|
        ns, name = *ns_name
        # Check whether this variable is assignable
        if o.is_a? Array or object_mapper.property?(o, ns, name)
          values = []

          homonymous_children.each do |child|
            values << ((child.is_a? Array and child.length == 1)? child.first : child)
          end

          if o.is_a? Array
            o.concat(values)
          elsif values.length == 1
            object_mapper.set_property(o, ns, name, values[0])
          else
            object_mapper.set_property(o, ns, name, values)
          end
        end
      end
      
      o
    end
    
  end

end

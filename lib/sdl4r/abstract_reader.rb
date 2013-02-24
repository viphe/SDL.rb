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
      v ? v.count : 0
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
    # @return [AbstractReader] returns an AbstractReader if a new node has been reached or +nil+ if the end of file
    #   has been reached.
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
    # is complete.
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
            node.attributes.each do |attribute|
              tag.set_attribute(attribute[0][0], attribute[0][1], attribute[1])
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

  end

end
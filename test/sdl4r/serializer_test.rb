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

# Work-around a bug in NetBeans (http://netbeans.org/bugzilla/show_bug.cgi?id=188653)
if ENV['NB_EXEC_EXTEXECUTION_PROCESS_UUID']
  $:[0] = File.join(File.dirname(__FILE__),'../../lib')
  $:.unshift(File.join(File.dirname(__FILE__),'../../test'))
end

module SDL4R

  require 'ostruct'
  require 'date'
  require 'test/unit'

  require 'sdl4r'
  require 'sdl4r/tag_writer'

  require 'sdl4r/sdl_test_case'

  class SerializerTest < Test::Unit::TestCase
    include SdlTestCase

    # Serializes the given object to a Tag structure and returns the root Tag.
    def serialize_to_tag(*args)
      writer = TagWriter.new
      writer.write(*args)
      writer.root
    end
    protected :serialize_to_tag

    def test_values_at_root_level
      root = serialize_to_tag([1, :abc, nil])
      assert_equal(<<EOS, SDL4R::dump(root))
1 "abc" null
EOS
    end

    def test_attributes_at_root_level
      mole = OpenStruct.new(:vision => 0.5)
      root = serialize_to_tag(mole)
      assert_equal(<<EOS, SDL4R::dump(root))
vision 0.5F
EOS
    end

    def test_basic_open_struct
      serializer = TagWriter.new

      car = OpenStruct.new
      car.brand = 'Opel'
      car.wheels = 4
      car.max_speed = 223.5
      car.radio = OpenStruct.new
      car.radio.brand = 'Pioneer'
      car.radio.signal_noise_ratio = 90
      car.radio.construction_date = Date.civil(2005, 12, 5)

      # serialize and check
      serializer.write(:car => car)
      tag = serializer.root

      assert_equal SDL4R::ROOT_TAG_NAME, tag.name
      assert_equal({}, tag.attributes, 'the root tag cannot have attributes')

      car_tag = tag.child(:car)
      assert_equal 1, car_tag.children.length
      assert_equal car.brand, car_tag.attribute('brand')
      assert_equal car.wheels, car_tag.attribute('wheels')
      assert_equal car.max_speed, car_tag.attribute('max_speed')
      assert_equal(
        { 'brand' => car.radio.brand, 'signal_noise_ratio' => car.radio.signal_noise_ratio,
          'construction_date' => car.radio.construction_date },
        car_tag.child('radio').attributes)
      assert !car.radio.has_children?

      # deserialize and check
      car2 = serializer.deserialize(tag)
      assert_equal car.brand, car2.brand
      assert_equal car.wheels, car2.wheels
      assert_equal car.max_speed, car2.max_speed
      assert_equal car.radio.brand, car2.radio.brand
      assert_equal car.radio.signal_noise_ratio, car2.radio.signal_noise_ratio
      assert_equal car.radio.construction_date, car2.radio.construction_date
    end

    # Class used for serialization tests
    # a is a private instance variable
    # b has a read accessor
    # c has read/write accessors
    # d has read/write accessors and the read accessor can take an optional parameter
    # e has read/write accessors and the read accessor takes a parameter (not a real accessor, then)
    class SerializeA
      
      def initialize(a, b, c, d, e)
        @a = a
        @b = b
        @c = c
        @d = d
        @e = e
      end

      attr_reader :b
      
      def c
        @c + 1
      end

      attr_writer :c

      def d(x = 0)
        @d + 1
      end

      attr_writer :d

      def e(x)
        @e + 1
      end

      attr_writer :e

    end

    def test_serialize_object_and_property_access
      o = SerializeA.new(10, 20, 30, 40, 50)

      serializer = TagWriter.new
      tag = serializer.write(:o => o).root.child(:o)

      assert_equal 10, tag.attribute('a')
      assert_equal 20, tag.attribute('b')
      # the read accessor should be have been used (it adds 1 to the serialized value)
      assert_equal 31, tag.attribute('c')
      # the read accessor should be have been used (it adds 1 to the serialized value)
      assert_equal 41, tag.attribute('d')
      # the read accessor has a wrong arity and therefore, 'e' should be considered a private variable
      assert_equal 50, tag.attribute('e')
    end

    def test_serialize_array_property
      o = OpenStruct.new
      o.array1 = [ 407, 5, 2.3 ]
      o.array2 = []
      o.array3 = [ OpenStruct.new(:some_values => [1, nil]), OpenStruct.new(:flavor => 'strawberry') ]

      top_tag = serialize_to_tag(:o => o)
      o_tag = top_tag.child(:o)

      assert_equal [ 407, 5, 2.3 ], o_tag.child('array1').values
      assert_equal [], o_tag.child('array2').values
      assert_equal Hash.new, o_tag.child(:array2).attributes

      array3_tags = o_tag.children('array3')
      assert_equal 2, array3_tags.size
      assert_equal [1, nil], array3_tags[0].child('some_values').values
      assert_equal 'strawberry', array3_tags[1].attribute('flavor')
    end

    def test_serialize_hash
      top = OpenStruct.new

      serializer = TagWriter.new
      top.h = {}
      tag = serializer.write(top).root
      assert_equal top.h, tag.child('h').attributes

      serializer = TagWriter.new
      top.h = { "a" => 10, "b" => "xyz", "c" => nil }
      tag = serializer.write(top).root
      assert_equal top.h, tag.child('h').attributes
    end

    class Top
      attr_reader :books
      def initialize
        @books = []
      end
    end

    class Book
      attr_accessor :title, :introduction, :conclusion, :keywords, :chapters
    end

    class Chapter
      attr_accessor :page, :title
    end

    def test_deserialize_object
      tag = SDL4R::read(<<EOS
books {
  book title="My Life, My Potatoes" {
    keywords "life" "potatoes"
    introduction page=12
    conclusion page=255
  }
  book {
    keywords "self-development"
    keywords "learning"
    keywords "paradoxal"
    title "Learn to Read in a Week"
    introduction page=3
    chapter page=5 title="A, B, C"
    chapter page=6 title="Read on my Lips"
  }
}
EOS
      )

      serializer = Serializer.new
      
      def serializer.new_plain_object(tag, o = nil, parent_object = nil)
        if parent_object.nil?
          Top.new
        elsif tag.name == "book"
          Book.new
        elsif parent_object.is_a? Book and ["introduction", "conclusion"].include?(tag.name)
          Chapter.new
        else
          super(tag, o, parent_object)
        end
      end

      def serializer.serialize_array_as_child_tags(name, array, parent_tag)
        if parent_tag.name == SDL4R::ROOT_TAG_NAME and name == "books"
          super("book", array, new_tag("books", array, parent_tag))
        else
          return super(name, array, parent_tag)
        end
      end

      def serializer.get_deserialized_property_name(tag, parent_tag, parent_object)
        if parent_tag.name == "book" and tag.name == "chapter"
          return "chapters"
        else
          super(tag, parent_tag, parent_object)
        end
      end

      top = serializer.deserialize(tag)
      check_book_hierarchy(top)

      top2 = serializer.deserialize(serializer.serialize(top))
      check_book_hierarchy(top2)
    end

    def check_book_hierarchy(top)
      assert_instance_of Top, top
      assert_instance_of Array, top.books
      assert_equal 2, top.books.length

      assert_instance_of Book, top.books[0]
      assert_equal "My Life, My Potatoes", top.books[0].title
      assert_equal ["life", "potatoes"], top.books[0].keywords
      assert_instance_of Chapter, top.books[0].introduction
      assert_equal 12, top.books[0].introduction.page
      assert_instance_of Chapter, top.books[0].conclusion
      assert_equal 255, top.books[0].conclusion.page

      assert_instance_of Book, top.books[1]
      assert_equal "Learn to Read in a Week", top.books[1].title
      assert_equal ["self-development", "learning", "paradoxal"], top.books[1].keywords
      assert_instance_of Chapter, top.books[1].introduction
      assert_equal 3, top.books[1].introduction.page
      assert_equal 2, top.books[1].chapters.length
      assert_equal 5, top.books[1].chapters[0].page
      assert_equal "A, B, C", top.books[1].chapters[0].title
      assert_equal 6, top.books[1].chapters[1].page
      assert_equal "Read on my Lips", top.books[1].chapters[1].title
      assert_nil top.books[1].conclusion
    end

    def test_option_omit_nil_properties
      o = OpenStruct.new(:a => 1, :b => nil)

      serializer = TagWriter.new(ObjectMapper.new(:omit_nil_properties => false))
      tag = serializer.write(:o => o).root.child
      assert_equal({ 'a' => 1, 'b' => nil }, tag.attributes)

      serializer = TagWriter.new(ObjectMapper.new(:omit_nil_properties => true))
      tag = serializer.write(:o => o).root.child
      assert_equal({ 'a' => 1 }, tag.attributes)
    end

    def test_deserialize_anonymous
      tag = SDL4R::read(<<EOS
colors {
  "red"
  "blue"
  "yellow"
  alpha 0.5
}
files {
  "readme.txt"
  "LICENSE.rtf"
}
matrix {
	1	2	3
	4	5	6
}
alone {
  "in the dark"
}
EOS
      )
      serializer = Serializer.new
      top = serializer.deserialize(tag)
      assert_equal ["red", "blue", "yellow"], top.colors.content
      assert_equal 0.5, top.colors.alpha
      assert_equal ["readme.txt", "LICENSE.rtf"], top.files
      assert_equal [[1, 2, 3], [4, 5, 6]], top.matrix
      assert_equal "in the dark", top.alone
    end

    def test_deserialize_root_as_hash
      tag = SDL4R::read(<<EOS
fingers 7
matrix {
	1	2	3
	4	5	6
}
EOS
      )
      serializer = Serializer.new
      top = serializer.deserialize(tag, Hash.new)
      assert_kind_of Hash, top
      assert_equal 7, top["fingers"]
      assert_equal [[1, 2, 3], [4, 5, 6]], top["matrix"]
    end

    def test_deserialized_properties_priorities
      top = SDL4R::load(<<EOS
fruit name="BANANA" {
  name "banana"
}
o1 "123" value="xyz"
o2 "123" value="xyz" {
  value 456
}
o3 content="xyz" {
  "123"
}
o4 content="xyz" {
  "123"
  content 456
}
o5 {
  "123"
}
EOS
      )

      assert_equal "banana", top.fruit.name
      assert_equal "xyz", top.o1.value
      assert_equal nil, top.o1.values # otherwise the previous assertion is not interesting
      assert_equal 456, top.o2.value
      assert_equal nil, top.o2.values # otherwise the previous assertion is not interesting
      assert_equal "xyz", top.o3.content
      # Any child tag named "content" is considered anonymous EVEN IF the name was explicit in the
      # SDL.
      assert_equal "xyz", top.o4.content
      assert_equal "123", top.o5 # otherwise the two previous assertions are not interesting
    end

    # This test will loop forever or make a stack error if the cycles are not handled property.
    def test_serialize_object_references
      top = OpenStruct.new
      o1 = OpenStruct.new(:name => '1')
      o2 = OpenStruct.new(:name => '2')
      o3 = OpenStruct.new(:name => '3')
      o4 = OpenStruct.new(:name => '4')

      top.worker = [o1, o2, o4]

      # cycles
      o1.slave = o2
      o1.myself = o1
      o2.master = o1
      o2.slave = o3
      o3.slave = o1

      serializer = TagWriter.new
      serializer.write(top)
      root = serializer.root

      assert_equal 3, root.child_count # o1, o2 and o4
      o1_tag, o2_tag, o4_tag = *root.children

      assert_equal '1', o1_tag.attribute(:name)
      assert_not_nil o1_tag.attribute(:oid), 'o1 should have an oid as referenced later in the graph'
      assert_equal o1_tag.attribute(:oid), o1_tag.child(:myself).attribute(:oref)

      assert_equal o2_tag.attribute(:oref), o1_tag.child(:slave).attribute(:oid)
      assert_equal '2', o1_tag.child(:slave).attribute(:name)
      assert_equal o1_tag.attribute(:oid), o1_tag.child(:slave).child(:master).attribute(:oref)

      o3_tag = o1_tag.child(:slave).child(:slave)
      assert_not_nil o3_tag
      assert_equal '3', o3_tag.attribute(:name)
      assert_equal o1_tag.attribute(:oid), o3_tag.child(:slave).attribute(:oref)

      assert_nil o2_tag.attribute(:name)
      assert_not_nil o2_tag.attribute(:oref)

      assert_nil o4_tag.attribute(:oid)
      assert_equal '4', o4_tag.attribute(:name)
    end

    def test_deserialize_object2
      tag = SDL4R::read(<<EOS
robot 'A' oid=14
robot 'B' oid=57 {
  me oref=57
  wife oref=14
  infant 'C' oid=110 {
    parent oref=14
    parent oref=57
  }
}
robot oref=110
EOS
      )

      serializer = Serializer.new
      top = serializer.deserialize(tag)

      assert_equal 3, top.robot.length
      assert_same top.robot[1], top.robot[1].me
      assert_same top.robot[0], top.robot[1].wife
      assert_same top.robot[2], top.robot[1].infant
      assert_same top.robot[0], top.robot[1].infant.parent[0]
      assert_same top.robot[1], top.robot[1].infant.parent[1]
    end

    class FromSdlA
      attr_accessor :firstname
      def from_sdl(tag, serializer = Serializer.new)
        self.firstname = tag.attribute("name")
        self
      end
    end

    def test_from_sdl
      serializer = Serializer.new
      def serializer.new_plain_object(tag, o = nil, parent_object = nil)
        if tag.name == 'player'
          FromSdlA.new
        else
          super(tag, o, parent_object)
        end
      end

      tag = SDL4R::read(<<EOS
player name="Roberto"
EOS
      )
      top = serializer.deserialize(tag)
      assert_kind_of FromSdlA, top.player
      assert_equal "Roberto", top.player.firstname

      tag = SDL4R::read(<<EOS
player name="Roberto"
player name="Georgio"
EOS
      )
      top = serializer.deserialize(tag)
      assert_kind_of FromSdlA, top.player[0]
      assert_equal "Roberto", top.player[0].firstname
      assert_kind_of FromSdlA, top.player[1]
      assert_equal "Georgio", top.player[1].firstname
    end

    class ToSdlA
      def initialize(firstname, lastname)
        @firstname = firstname
        @lastname = lastname
      end

      def to_sdl(writer)
        writer.attribute(:fullname, @firstname + ' ' + @lastname)
      end
    end

    def test_to_sdl
      s = SDL4R::dump(:knight => ToSdlA.new('Lancelot', 'du Lac'))
      assert_equal("knight fullname=\"Lancelot du Lac\"\n", s)

      s = SDL4R::dump(:knight => [ToSdlA.new('Lancelot', 'du Lac'), ToSdlA.new('Perceval', 'Halla')])
      assert_equal(<<EOS.gsub(/^ +/, ''), s)
knight fullname="Lancelot du Lac"
knight fullname="Perceval Halla"
EOS
    end

    def test_default_namespace
      serializer = TagWriter.new(ObjectMapper.new(:default_namespace => "ns"))

      origin = OpenStruct.new(:name => "Bourgogne")
      wine1 = OpenStruct.new(:color => "red", :origin => origin)
      wine2 = OpenStruct.new(:color => "white", :origin => origin)


      assert_equal(
        Tag.new(SDL4R::ROOT_TAG_NAME) do
          new_child("ns", "wine") do
            set_attribute("color", "red") # no namespace on attributes
            new_child("ns", "origin") do
              set_attribute("name", "Bourgogne")
              set_attribute("oid", 2)
            end
          end
          new_child("ns", "wine") do
            set_attribute("color", "white") # no namespace on attributes
            new_child("ns", "origin") do
              set_attribute(ObjectMapper::OBJECT_REF_ATTR_NAME, 2)
            end
          end
        end,
        serializer.serialize("wine" => [wine1, wine2]))
    end
  end

end

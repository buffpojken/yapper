describe 'Criteria' do
  before do
    class WhereDocument
      include Yapper::Document

      field :field1, :type => String
      field :field2, :type => Integer
      field :field3, :type => Time
      field :field4, :type => String
      field :field5, :type => Boolean

      index :field1, :field2, :field3, :field5
    end
    class AnotherWhereDocument
      include Yapper::Document

      field :field1, :type => String
      field :field2

      index :field1
    end
  end
  before { Yapper::DB.instance.purge }
  after { Object.send(:remove_const, 'WhereDocument') }
  after { Object.send(:remove_const, 'AnotherWhereDocument') }

  describe 'when changing the index definition' do
    it "reindexes the fields" do
      WhereDocument.create(:field1 => 'field1', :field4 => 'field4')

      lambda {
        WhereDocument.where(:field4 => 'field4').first
      }.should.raise

      WhereDocument.class_eval do
        index :field4
      end

      WhereDocument.where(:field4 => 'field4').count.should == 1
    end
  end

  describe 'with no documents created' do
    it 'returns []' do
      WhereDocument.where(:field1 => 'xxx').to_a.should == []
    end
  end

  describe 'when searching with a non indexed field' do
    it 'raises' do
      lambda {
        AnotherWhereDocument.where(:field2 => 'xxx').first
      }.should.raise
    end
  end

  describe 'with documents created' do
    before do
      @now = Time.now
      WhereDocument.create(:field1 => 'field1_value', :field2 => 2)
      WhereDocument.create(:field1 => 'field1_value', :field2 => 3)
      WhereDocument.create(:field1 => 'field1_value', :field2 => 4)
      WhereDocument.create(:field1 => 'field1_other_value', :field2 => 1)
      WhereDocument.create(:field1 => 'field1_other_value', :field2 => 2, :field3 => @now)
      WhereDocument.create(:field5 => true)
      AnotherWhereDocument.create(:field1 => 'field1_value', :field2 => 2)
    end

    describe '#all' do
      it 'returns all documents' do
        WhereDocument.all.to_a.count.should == 6
      end

      it 'returns documents that do not contain changes' do
        WhereDocument.all.first.changes.should == {}
      end

      describe 'with a document that has no indexes' do
        before do
          class NoIndexDocument
            include Yapper::Document

            field :field1
          end
        end

        it 'still returns' do
          NoIndexDocument.all.count.should == 0
          NoIndexDocument.all.to_a.count.should == 0
        end
      end
    end

    describe '#count' do
      it 'returns all documents' do
        WhereDocument.count.should == 6
      end
    end

    describe 'chaining' do
      it 'where, all' do
        WhereDocument.all.where(:field1 => 'field1_value').where(:field2 => 2).count.should == 1
      end

      it 'where, desc, asc' do
        WhereDocument.where(:field1 => 'field1_value').asc(:field2).first.field2.should == 2
      end

      it 'desc, asc' do
        WhereDocument.where(:field1 => 'field1_value').desc(:field1).desc(:field2).first.field2.should == 4
        WhereDocument.where(:field1 => 'field1_value').desc(:field1).asc(:field2).first.field2.should == 2
      end
    end

    it 'can search by string' do
      WhereDocument.where(:field1 => 'field1_value').count.should == 3
    end

    it 'can search by integer' do
      WhereDocument.where(:field2 => 2).count.should == 2
    end

    it 'can search by time' do
      WhereDocument.where(:field3 => @now).count.should == 1
    end

    it 'can search by boolean' do
      WhereDocument.where(:field5 => true).count.should == 1
      WhereDocument.where(:field5 => false).count.should == 0
    end

    it 'returns [] when looking up a non-existant doc' do
      WhereDocument.where(:field1 => 'xxx').to_a.should == []
    end

    it 'can select docments matching on multiple fields' do
      WhereDocument.where(:field1 => 'field1_value', :field2 => 2).to_a.count.should == 1
    end

    it 'can search using different operands' do
      WhereDocument.where(:field2 => { ">" => 1 }).count.should == 4
      WhereDocument.where(:field2 => { ">=" => 1 }).count.should == 5
    end

    describe 'when documents are updated' do
      before do
        WhereDocument.where(:field1 => 'field1_value').each { |doc| doc.update_attributes(:field1 => 'field1_value_updated', :field2 => 10) }
      end

      it 'searches by the updated values' do
        WhereDocument.where(:field1 => 'field1_value').count.should == 0
        WhereDocument.where(:field1 => 'field1_value_updated', :field2 => 10).count.should == 3
      end
    end
  end

  describe 'when a document is created without all fields being set' do
    before do
      WhereDocument.create(:field1 => 'field1_value')
    end

    it 'searches by the field' do
      WhereDocument.where(:field1 => 'field1_value').count.should == 1
    end

    describe 'when the document is updated to set a field that was not set before' do
      before do
        WhereDocument.where(:field1 => 'field1_value').first.update_attributes(:field2 => 10)
      end

      it 'searches by the updated field' do
        WhereDocument.where(:field2 => 10).count.should == 1
      end
    end
  end

  describe 'when sorting' do
    describe 'with text field' do
      before do
        WhereDocument.create(:field1 => 'apple')
        WhereDocument.create(:field1 => 'squash')
        WhereDocument.create(:field1 => 'carrot')
        WhereDocument.create(:field1 => nil)
      end
      it 'can sort documents ascending' do
        WhereDocument.asc(:field1).to_a.collect(&:field1).should == [nil, 'apple', 'carrot', 'squash']
      end

      it 'can sort documents descending' do
        WhereDocument.desc(:field1).to_a.collect(&:field1).should == ['squash', 'carrot', 'apple', nil]
      end
    end

    describe 'with date field' do
      before do
        WhereDocument.create(:field3 => Time.utc(2013,1,1,10,00))
        WhereDocument.create(:field3 => Time.utc(2013,1,1,9,00))
        WhereDocument.create(:field3 => Time.utc(2013,1,1,14,00))
      end
      it 'can sort documents ascending' do
        WhereDocument.asc(:field3).to_a.collect(&:field3).should == [Time.utc(2013,1,1,9,00), Time.utc(2013,1,1,10,00), Time.utc(2013,1,1,14,00)]
      end

      it 'can sort documents descending' do
        WhereDocument.desc(:field3).to_a.collect(&:field3).should == [Time.utc(2013,1,1,14,00), Time.utc(2013,1,1,10,00), Time.utc(2013,1,1,9,00)]
      end
    end
  end
end

describe 'Yapper persisting documents' do
  before do
    class Document
      include Yapper::Document

      field :field_1
      field :field_2
    end
  end
  before { Yapper::DB.instance.purge }
  after  { Object.send(:remove_const, 'Document') }

  describe 'creating documents' do
    it 'supports storing hashes by stringifying keys (to avoid symbol serialization bug)' do
      10.times { Document.create.tap { |doc| doc.update_attributes(:field_1 => { :a => [ { :a => 10 } ] }) } }
      Document.all.each { |doc| doc.field_1[:b] = 'b'; doc.save }

      Document.all.each { |doc| doc.field_1.should == { 'a' => [ { 'a' => 10 } ], 'b' => 'b' } }
    end

    it 'supports storing Time' do
      time = Time.now
      Document.create(:field_1 => time)

      Document.all.first.field_1.should == time
    end

    it 'tracks changes' do
      doc = Document.new
      doc.field_1 = 'field1'
      doc.field_2 = 'field2'

      doc.changes.should == { 'id' => doc.id,
                              'field_1' => 'field1',
                              'field_2'  => 'field2' }
    end

    describe "when using #new then #save" do
      it 'persists the fields' do
        doc = Document.new
        doc.field_1 = 'field1'
        doc.field_2 = 'field2'
        doc.new_record?.should == true
        doc.save

        doc = Document.find(doc.id)
        doc.new_record?.should == false
        doc.field_1.should == 'field1'
        doc.field_2.should == 'field2'
      end
    end

    describe "when using #create" do
      it 'persists the fields' do
        doc = Document.create(:field_1 => 'field1',
                              :field_2 => 'field2')

        doc = Document.find(doc.id)
        doc.field_1.should == 'field1'
        doc.field_2.should == 'field2'
      end
    end
  end

  describe 'updating documents' do
    before do
      @doc = Document.create(:field_1 => 'field1')
    end

    it 'tracks changes' do
      @doc.field_1 = 'field1_changed'

      @doc.changes.should == { 'field_1' => 'field1_changed' }

      @doc.save

      @doc.changes.should == {}
      @doc.previous_changes.should == { 'field_1' => 'field1_changed' }
    end

    it 'saves a false value' do
      @doc.update_attributes(:field_1 => false)

      @doc.reload.field_1.should == false
    end

    describe "when updating fields and then #save" do
      it 'persists the fields' do
        @doc.field_1 = 'field1_updated'
        @doc.save

        doc = Document.find(@doc.id)
        doc.field_1.should == 'field1_updated'
      end
    end

    describe "when using #update_attributes" do
      it 'persists the fields' do
        @doc.update_attributes(:field_1 => 'field1_updated')

        doc = Document.find(@doc.id)
        doc.field_1.should == 'field1_updated'
      end
    end
  end

  describe 'destroying documents' do
    before do
      @doc = Document.create(:field_1 => 'field1')
    end

    it 'destroys the document' do
      @doc.destroy

      Document.find(@doc.id).should == nil
    end
  end

  describe '#delete_all' do
    before do
      3.times { Document.create(:field_1 => 'field1') }
    end

    it 'deletes all documents' do
      Document.delete_all

      Document.all.count.should == 0
    end
  end
end

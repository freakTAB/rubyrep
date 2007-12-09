require File.dirname(__FILE__) + '/spec_helper.rb'

include RR

describe ProxyCursor do
  before(:each) do
    Initializer.configuration = proxied_config
  end

  it "initialize should store session and table and cache the primary keys of table" do
    session = create_mock_session 'dummy_table', ['dummy_key']
    
    cursor = ProxyCursor.new session, 'dummy_table'
    
    cursor.session.should == session
    cursor.table.should == 'dummy_table'
    cursor.primary_key_names.should == ['dummy_key']
  end
  
  it "construct_query should handle queries without any conditions" do
    session = create_mock_session 'dummy_table', ['dummy_key'], ['dummy_key', 'dummy_column']
    
    ProxyCursor.new(session, 'dummy_table').construct_query \
      .should == 'select dummy_key, dummy_column from dummy_table order by dummy_key'    
  end
  
  it "construct_query should handle queries with only a from condition" do
    session = create_mock_session 'dummy_table', ['dummy_key'], ['dummy_key', 'dummy_column']
    
    ProxyCursor.new(session, 'dummy_table').construct_query({'dummy_key' => 1}) \
      .should == "\
         select dummy_key, dummy_column from dummy_table \
         where (dummy_key) >= (1) order by dummy_key".strip!.squeeze!(' ')
  end
  
  it "construct_query should handle queries with only a to condition" do
    session = create_mock_session 'dummy_table', ['dummy_key'], ['dummy_key', 'dummy_column']
    
    ProxyCursor.new(session, 'dummy_table').construct_query(nil, {'dummy_key' => 1}) \
      .should == "\
         select dummy_key, dummy_column from dummy_table \
         where (dummy_key) <= (1) order by dummy_key".strip!.squeeze!(' ')
  end
  
  it "construct_query should handle queries with both from and to conditions" do
    session = create_mock_session 'dummy_table', ['dummy_key'], ['dummy_key', 'dummy_column']
    
    ProxyCursor.new(session, 'dummy_table').construct_query({'dummy_key' => 0}, {'dummy_key' => 1}) \
      .should == "\
        select dummy_key, dummy_column from dummy_table \
        where (dummy_key) >= (0) and (dummy_key) <= (1) order by dummy_key".strip!.squeeze!(' ')
  end
  
  it "construct_query should handle tables with combined primary keys" do
    session = create_mock_session 'dummy_table', 
      ['dummy_key1', 'dummy_key2'], 
      ['dummy_key1', 'dummy_key2', 'dummy_column']
    
    ProxyCursor.new(session, 'dummy_table').construct_query(
      {'dummy_key1' => 0, 'dummy_key2' => 1}, 
      {'dummy_key1' => 2, 'dummy_key2' => 3}) \
      .should == "\
        select dummy_key1, dummy_key2, dummy_column from dummy_table \
        where (dummy_key1, dummy_key2) >= (0, 1) and (dummy_key1, dummy_key2) <= (2, 3) \
        order by dummy_key1, dummy_key2".strip!.squeeze!(' ')
  end
  
  it "construct_query should quote column values" do
    session = ProxySession.new Initializer.configuration.left
    
    cursor = ProxyCursor.new(session, 'scanner_text_key')
    cursor.construct_query({'text_id' => 'a'},{'text_id' => 'b'}) \
      .should == "\
        select text_id, name from scanner_text_key \
        where (text_id) >= (E'a') and (text_id) <= (E'b') \
        order by text_id".strip!.squeeze!(' ')
    # additional check that the 'E' inserted through the quoting actually works
    results = cursor.prepare_fetch({'text_id' => 'a'},{'text_id' => 'b'})
    results.next_row.should == {'text_id' => 'a', 'name' => 'Alice'}
    results.next_row.should == {'text_id' => 'b', 'name' => 'Bob'}
    results.next?.should be_false
  end
  
  it "start_query should initiate the query and wrap it for type casting" do
    session = ProxySession.new Initializer.configuration.left
    
    cursor = ProxyCursor.new(session, 'scanner_records')
    cursor.prepare_fetch
    cursor.cursor.should be_an_instance_of(TypeCastingCursor)
    cursor.cursor.next_row.should == {'id' => 1, 'name' => 'Alice - exists in both databases'}
    
  end
  
  it "destroy should clear and nil the cursor" do
    session = create_mock_session 'dummy_table', ['dummy_key']
    cursor = ProxyCursor.new session, 'dummy_table'
    
    table_cursor = mock("DBCursor")
    table_cursor.should_receive(:clear)
    cursor.cursor = table_cursor
    
    cursor.destroy  
    cursor.cursor.should be_nil
  end  
end

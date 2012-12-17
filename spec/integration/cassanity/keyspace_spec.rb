require 'helper'
require 'cassanity/keyspace'
require 'cassanity/executors/cassandra_cql'

describe Cassanity::Keyspace do
  let(:keyspace_name)              { 'cassanity_test' }
  let(:self_created_keyspace_name) { 'self_created' }
  let(:column_family_name)         { 'apps' }

  let(:client) {
    CassandraCQL::Database.new('127.0.0.1:9160', {
      cql_version: '3.0.0',
    })
  }

  let(:executor) {
    Cassanity::Executors::CassandraCql.new({
      client: client,
    })
  }

  let(:required_arguments) {
    {
      name: keyspace_name,
      executor: executor,
    }
  }

  subject {
    described_class.new(required_arguments)
  }

  before do
    client_drop_keyspace(client, keyspace_name)
    client_create_keyspace(client, keyspace_name)
  end

  after do
    client_drop_keyspace(client, keyspace_name)
    client_drop_keyspace(client, self_created_keyspace_name)
  end

  it "can create" do
    client_keyspace?(client, self_created_keyspace_name).should be_false
    instance = described_class.new(required_arguments.merge({
      name: self_created_keyspace_name,
    }))
    instance.create
    client_keyspace?(client, self_created_keyspace_name).should be_true
  end

  it "knows if it exists" do
    subject.exists?.should be_true
    client_drop_keyspace(client, keyspace_name)
    subject.exists?.should be_false
  end

  it "can recreate when not created" do
    client_drop_keyspace(client, keyspace_name)
    client_keyspace?(client, keyspace_name).should be_false
    subject.recreate
    client_keyspace?(client, keyspace_name).should be_true
  end

  it "can recreate when already created" do
    client_keyspace?(client, keyspace_name).should be_true
    subject.recreate
    client_keyspace?(client, keyspace_name).should be_true
  end

  it "can use" do
    client.execute("USE system")
    client.keyspace.should_not eq(keyspace_name)
    subject.use
    client.keyspace.should eq(keyspace_name)
  end

  it "can drop" do
    client_keyspace?(client, keyspace_name).should be_true
    subject.drop
    client_keyspace?(client, keyspace_name).should be_false
  end

  it "knows column families" do
    client_create_column_family(client, 'something1')
    client_create_column_family(client, 'something2')

    result = subject.column_families
    result.each do |column_family|
      column_family.should be_instance_of(Cassanity::ColumnFamily)
      column_family.keyspace.should eq(subject)
    end

    names = result.map(&:name)
    names.should include('something1')
    names.should include('something2')

    client_drop_column_family(client, 'something1')
    client_drop_column_family(client, 'something2')
  end
end
class Fixturies

    class << self

        attr_reader :fixtures_directory

        def build(*things, &proc)
            meth_name = :"builder_#{rand}"
            define_method meth_name, &proc
            things.each do |thing|
                thing.is_a?(String) ? table(thing) : model(thing)
            end
            builders << meth_name
        end

        def set_fixtures_directory(dir)
            @fixtures_directory = dir
        end

        def create_fixtures
            self.new.create_fixtures
        end

        def table(table_name)
            self.table_names << table_name
        end

        def model(model_klass)
            self.table_names << model_klass.table_name
        end 

        def table_names
            unless defined? @table_names
                @table_names = Set.new 
            end
            @table_names
        end

        def builders
            unless defined? @builders
                @builders = []
            end
            @builders
        end

    end

    attr_reader :record_identifiers

    def initialize
        @record_identifiers = {}
    end

    def create_fixtures
        clear_db
        build_all_records
        create_fixture_files
    end

    def build_all_records
        self.class.builders.each do |builder|
            send(builder)
        end
    end

    def identify(record, name)
        if record.id.nil?
            raise ArgumentError.new("No id for record.  Must be saved before calling identify")
        end
        record_identifiers[record_key(record)] = name
    end

    private
    def record_key(record)
        "#{record.class.table_name}#{record.id}"
    end

    private
    def create_fixture_files

        if self.class.fixtures_directory.nil?
            raise "No fixtures_directory set.  You must call set_fixtures_directory 'path/to/directory'"
        end

        FileUtils.mkdir_p(self.class.fixtures_directory)

        self.class.table_names.each do |table_name|
            
            # create a simple ActiveRecord klass to connect
            # to the table and handle querying for us
            klass = Class.new(ActiveRecord::Base) {
                self.table_name = table_name
            }

            hash = {}
            klass.all.each_with_index do |record, i|
                name = record_identifiers[record_key(record)] || "#{table_name.singularize}_#{i}"
                hash[name] = record.attributes
            end
            
            File.open(Rails.root.join(self.class.fixtures_directory, "#{table_name}.yml"), 'w+') do |f|
                f.write(hash.to_yaml)
            end

        end
    end

    private
    def clear_db
        self.class.table_names.each do |table_name|
            quoted_table_name = ActiveRecord::Base.connection.quote_table_name(table_name)
            sql = "DELETE FROM #{quoted_table_name} "
            ActiveRecord::Base.connection.delete(sql, "#{quoted_table_name} Delete all")
        end
        
    end

end
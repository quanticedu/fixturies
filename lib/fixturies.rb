class Fixturies

    class << self

        attr_reader :fixtures_directory, :fixture_class_names

        def build(&proc)
            meth_name = :"builder_#{rand}"
            define_method meth_name, &proc
            builders << meth_name
        end

        def set_fixtures_directory(dir)
            @fixtures_directory = dir
        end

        def set_fixture_class(class_names = {})
            @fixture_class_names ||= {}
            @fixture_class_names = fixture_class_names.merge(class_names.stringify_keys)
        end

        def create_fixtures
            self.new.create_fixtures
        end

        def table_names
            @all_table_names ||= ActiveRecord::Base.connection.execute("
                SELECT table_name
                FROM information_schema.tables
                WHERE
                    table_schema = 'public'
                    AND table_type = 'BASE TABLE'
            ").to_a.map { |r| r['table_name'] }

            @all_table_names - table_names_to_skip
        end

        # you can add more tables to this if necessary.  For example,
        # we had to add spatial_ref_sys, which is created by the
        # postgis extension
        def table_names_to_skip
            @table_names_to_skip ||= ['schema_migrations']
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

        # ensure that we are not assigning the same name to two
        # different records
        @records_by_name ||= {}
        @records_by_name[record.class.table_name] ||= {}
        existing_entry = @records_by_name[record.class.table_name][name]
        if existing_entry && existing_entry != record
            raise "Cannot assign the name #{name.inspect} to two different #{record.class.table_name}"
        end
        @records_by_name[record.class.table_name][name] = record

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

        self.class.table_names.sort.each do |table_name|

            filename = Rails.root.join(self.class.fixtures_directory, "#{table_name}.yml")
            File.delete(filename) if File.exist?(filename)

            # create a simple ActiveRecord klass to connect
            # to the table and handle querying for us
            klass = Class.new(ActiveRecord::Base) {
                self.table_name = table_name
                self.inheritance_column = nil # do not blow up if the type column indicates we should be using single-table inheritance
            }

            virtual_column_names = klass.columns.filter_map do |column|
              if column.virtual?
                  column.name
              end
            end

            hash = {}
            klass.all.each_with_index do |record, i|
                name = record_identifiers[record_key(record)] || "#{table_name.singularize}_#{i}"
                attributes = record.attributes
                virtual_column_names.each do |column_name|
                    attributes.delete(column_name)
                end
                hash[name] = attributes
            end

            if hash.any?
                # Rails allows baking the model_class into the YAML file, which
                # can be useful if the class cannot be inferred from the table_name.
                # See https://github.com/rails/rails/pull/20574/files
                klass = self.class.fixture_class_names&.[](table_name)
                hash['_fixture'] = {'model_class' => klass.to_s} if klass.present?

                File.open(filename, 'w+') do |f|
                    f.write(hash.to_yaml)
                end
            end

        end
    end

    private
    def clear_db
        self.class.table_names.each do |table_name|
            # Note: This does not handle foreign key constraints.  See Readme for a solution
            quoted_table_name = ActiveRecord::Base.connection.quote_table_name(table_name)
            sql = "DELETE FROM #{quoted_table_name} "
            ActiveRecord::Base.connection.delete(sql, "#{quoted_table_name} Delete all")
        end

    end

end

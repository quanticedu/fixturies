# Fixturies

When factories are too slow and fixtures are too hard to maintain, use **fixturies**.

With **fixturies** you use factories to build your fixtures.  Then you get the speed
of fixtures and the maintanability of factories.

## You may need fixturies if ...

You are using factories in your tests to re-create the same records over and over
again, and your tests are running too slowly.

## Our Story

Read our blog post about how we made our tests run 10 times faster without making them any harder to maintain at [blog.smart.ly](http://blog.smart.ly/tag/unit-tests/)

## Install

add `gem 'fixturies'` to `Gemfile`

## Usage

    ## define a subclass of Fixturies
    class FixtureBuilder < Fixturies

      # Use `set_fixtures_directory` to tell Fixturies
      # where to put all of the fixtures files
      set_fixtures_directory Rails.root.join('spec', 'fixtures')

      # By default, fixturies will create a fixtures file for
      # every table in your public schema, except for `schema_migrations`.
      # If there are other tables for which you do not want fixture files,
      # add them to `table_names_to_skip`
      table_names_to_skip << ['spatial_ref_sys']

      # Use the `build` method to create
      # the records you want available to your tests.
      build do
          3.times do |i|
            User.create!({
              email: "my_user_#{i}@example.com"
            })
          end
      end

      # You can add a specific name to a fixture using the
      # identify method
      build(User) do
          my_user = User.create!(email: 'fred@example.com')
          identify(my_user, 'fred')
      end

    end


Calling `FixtureBuilder.create_fixtures` will now create the following files:

/spec/fixtures/users.yml

    ---
    user_0:
      id: 62
      email: my_user_0@example.com
    user_1:
      id: 63
      email: my_user_1@example.com
    user_2:
      id: 64
      email: my_user_2@example.com
    user_3:
      id: 65
      email: admin@example.com
    fred:
      id: 66
      email: fred@example.com

/spec/fixtures/roles.yml

    ---
    role_0:
      id: 79
      name: admin

/spec/fixtures/users_roles.yml

    ---
    users_role_0:
      user_id: 65
      role_id: 79


## Notes

 * We call `FactoryGirl.create_fixtures` from our spec_helper.rb file.  This means that the fixture files
   are re-built once each time we run tests.
 * We add our fixture files to .gitignore
 * We use the factory library FactoryGirl.  So our build calls look like:

        build(User) do
          FactoryGirl.create_list(:user, 4)
        end

   That also means that we can still use FactoryGirl in tests where need to create a specific record for use in just one test.

 * Right now, the code that clears out the database is not smart enough to deal with foreign key constraints.  In postgres (and maybe other dbs?) you can get around this by overriding clear_db in your subclass of Fixturies like below.  If you have another solution that is mroe general, please let me know or file a pull request.

        def clear_db
            self.class.table_names.each do |table_name|
                quoted_table_name = ActiveRecord::Base.connection.quote_table_name(table_name)
                ActiveRecord::Base.connection.execute("TRUNCATE #{quoted_table_name} CASCADE")
            end

        end


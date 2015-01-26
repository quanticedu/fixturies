# Fixturies

When factories are too slow and fixtures are too hard to maintain, use **fixturies**.

With **fixturies** you use factories to build your fixtures.  Then you get the speed
of fixtures and the maintanability of factories.

## You may need fixturies if ...

You are using factories in your tests to re-create the same records over and over
again, and your tests are running too slowly.

## Our Story

We had a rails app.  We used factories in our tests, and it took ten minutes to run them all.

We suspected that a lot of the time was in the factories, probably in things like validations and callbacks, but it was a little hard to track down exactly where the time was going.  We wanted the callbacks and validations to run once to ensure the validity of the records we were using in tests, but we didn't need them to run over and over as we re-created identical records for each test.  

But we didn't want to just switch to fixtures, because factories are easier to use and because they would ensure that the records we use in tests remain in line with records created by our changing codebase.

So we wrote fixturies.  And our tests ran in 1 minute.  10x faster.  And we rejoiced.

## Usage

    ## define a subclass of Fixturies
    class FixtureBuilder < Fixturies

      # Use `set_fixtures_directory` to tell Fixturies 
      # where to put all of the fixtures files
      set_fixtures_directory Rails.root.join('spec', 'fixtures')

      # Use the `build` method to create
      # the records you want available to your tests.
      #
      # Arguments are one or more active record
      # classes and a block.
      # 
      # Any active record class passed to `build` will have
      # a fixture file created for it.  The file will include
      # any records created inside the block.
      # (It is safe to pass the same class to multiple
      # `build` calls.  You will still end up with a single fixture
      # file including all the records) 
      build(User) do
          3.times do |i|
            User.create!({
              email: "my_user_#{i}@example.com"
            })
          end
      end

      # If records are created in a table that does not 
      # have an associated active record class, you can just
      # pass the table's name into `build`. 
      #
      # In this case, roles are attached to users through
      # a users_roles table that does not have an associated
      # ActiveRecord class.  By passing 'user_roles' into `build`, we
      # tell Fixturies that it needs to write a fixture file
      # for that table as well
      build(User, 'users_roles', Role) do
          my_user = User.new(email: "admin@example.com")

          # `add_role` creates a record in the roles table and
          # a record in the users_roles join table. Both records
          # will have fixtures created for them (see fixture files
          # below)
          my_user.add_role('admin')
          my_user.save!
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

 * We call `create_fixtures` from our spec_helper.rb file.  This means that the fixture files
   are re-built once each time we run tests.
 * We add our fixture files to .gitignore
 * We use the factory library FactoryGirl.  So our build calls look like:

        build(User) do
          FactoryGirl.create_list(:user, 4)
        end

   That also means that we can still use FactoryGirl in tests where need to create a specific record for use in just one test.
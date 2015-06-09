# Mocks as Proof Assumptions

Each test in a system's test suite can be seen as a proof of some property under a particular set of assumptions about the environment. Seeing tests as proofs is beneficial in a few ways.

If we can format test output by listing the assumptions and the tested property in the form of a proof, the tests become a more useful form of documentation. This is a natural extension of tests as a specification for a system.

Also, inlining assumptions to get better documentation in the form of proofs promotes better sharing of assumptions across tests and better use of testing tools for documentation. Better tests beget better docs beget better tests.

Here, we examine these claims by modifying the [RSpec](https://github.com/rspec/rspec-core) and [Mocha](https://github.com/freerange/mocha) DSL methods to provide test output from the [Discourse](https://github.com/discourse/discourse) web application in the structure (vaguely) of a proof. The end goal is to provide documentation derived from the test suite that is more useful to a new developer of the system than the default RSpec test output or the test code.

## Not So Docs Though

To see how formatting test output as a proof can provide useful documentation we will examine an example from the Discourse's [spec for the `ComposerMessageFinder`](https://github.com/discourse/discourse/blob/master/spec/components/composer_messages_finder_spec.rb#L33) with some minor modifications (`let` to `let!` and one `let` to `subject!`).

```ruby
describe ComposerMessagesFinder do
  context '.check_education_message' do
    let!(:user) { Fabricate.build(:user) }

    context 'creating topic' do
      subject!(:finder) do
        ComposerMessagesFinder.new(user, composerAction: 'createTopic')
      end

      before do
        SiteSetting.stubs(:educate_until_posts).returns(10)
      end

      it "returns a message for a user who has not posted any topics" do
        user.expects(:created_topic_count).returns(9)
        expect(finder.check_education_message).to be_present
      end
    end
  end
end
```

The key parts are the `let!`, `subject!`, `stubs`, `expects`, and `returns` method calls that are part of the RSpec and Mocha DSLs. Each call to these methods represents an assumption about the system under which the test is expected to pass. This makes them critical to understanding the test itself.

In fact, the original purpose of the DSL is to make the code read like english documentation ... it just doesn't work particularly well. The critical issue is that the code, which is a set of precise instructions for execution, is too detailed. The important ideas are lost.

Further, the "documentation" output from RSpec is anemic, using only the `describe` and `context` definitions. As an example, the output of the above test:

<pre>
$ bundle exec rspec --format d spec/components/composer_messages_finder_spec.rb
ComposerMessagesFinder
  .check_education_message
    creating topic
      returns a message for a user who has not posted any topics
</pre>

As a new user to the system neither the code nor the test output are a useful set of documentation.

### Improving the Test Output

Viewing the tests through the lense of a proof gives us a structure to follow. With minor modifications to the DSL methods listed above we can track the assumptions for each test and inline them for review with each outcome as described by the `context` method.

<pre>
$ bundle exec rspec --format d spec/components/composer_messages_finder_spec.rb
ComposerMessagesFinder
  .check_education_message
    creating topic
	  Assuming:
        `user` exists, instance of User
        `finder` exists, instance of ComposerMessagesFinder
        SiteSetting, sent `educate_until_posts` returns 10
        `user`, sent `created_topic_count` returns 9
      The test proves:
        `finder` returns a message for a user who has not posted any topics
</pre>

**Note** What's wrong with the proved property relative to the assumptions?

This is an improvement in a few ways:

1. It provides context for the test: getting a message from the finder depends on the user and getting a topic count from the user forms an implicit dependency on the notion of topics owned by the user.
2. It highlights system properties: `SiteSetting` is the central place to define constants in the application.
3. It calls out awkward inconsistencies in the test description: "has not posted any topics" should be something like "has not posted enough topics".
4. As pointed out in class, it's nice to have the assumptions inlined with the tested property for easy consumption (Thanks Ryan and Alex).

## Virtuous Cycle

To see how this format for test output promotes better tests, we will again borrowing from Discourse, this time from the [`CategoryList` spec](https://github.com/discourse/discourse/blob/master/spec/components/category_list_spec.rb). First we will examine how strengthening the argument of the proof corresponds with accurate placement of assumptions and then see how using RSpec's DSL can improve the test output and the tests themselves.

### Weak Arguments

It's frequently the case that extra assumptions are defined for tests that don't require them. This corresponds with the notion of [weakening](http://en.wikipedia.org/wiki/Structural_rule) in proofs. Intuitively, if we could prove the property with fewer assumptions it would be a stronger argument. Here, it would result in better documentation.

```ruby
describe CategoryList do
  let(:user) { Fabricate(:user) }
  let(:admin) { Fabricate(:admin) }
  let(:category_list) { CategoryList.new(Guardian.new user) }

  context "security" do
    ...
  end

  context "with a category" do
    let!(:topic_category) { Fabricate(:category) }
    context "without a featured topic" do
      it "should not return empty categories" do
	    # ! First reference of `category_list`
        expect(category_list.categories).to be_blank
      end
      ...
    end
  end
  ...
end
```

The important thing to note is that `category_list` is only used in the "with a category" context, but it will show up in the assumptions output for every other test in the test suite:
<pre>
CategoryList
  security
    admin list
      Assuming:
        `user` exists, instance of User
        `admin` exists, instance of User
        `category_list` exists, instance of CategoryList
        `admin_list` exists, instance of CategoryList
      The test proves:
        `admin_list` shows one secure category
</pre>

Here, the extra `category_list` definition might lead a user to believe that it has some bearing on the test, causing confusion. By moving the the `category_list` into the "with category" context the user can be rid of the extraneous assumption in other test output.


### `let`s Get `subject`ive

Most of the tests in the Discourse test suite don't have an explicit subject object that's being tested. That is, the tests are not focused on a particular property of a particular object. In our proof format output the property being proved, e.g. "`admin_list` shows one secure category" requires a subject definition. Similarly tests should be focused on a particular object property.

```ruby
describe CategoryList do
  ...
  context "security" do
    it "properly hide secure categories" do
      cat = Fabricate(:category)
      Fabricate(:topic, category: cat)
      cat.set_permissions(:admins => :full)
      cat.save

      # uncategorized + this
      expect(CategoryList.new(Guardian.new admin).categories.count).to eq(2)
      expect(CategoryList.new(Guardian.new user).categories.count).to eq(0)
      expect(CategoryList.new(Guardian.new nil).categories.count).to eq(0)
    end
    ...
  end
end
```

The `it` here is murky, but the test focuses on how the `CategoryList` manages the categories it produces through a `Guardian`.  In terms of a proof this is very awkward, you can't really quantify over all instances of `CategoryList`s since the proof depends on the state of each instance. Similarly it's hard to produce useful output for documentation in this case, since we don't have a targeted subject:

<pre>
  security
    Assuming:
      `user` exists, instance of User
      `admin` exists, instance of User
      `private_cat` exists, instance of Category
    The test proves:
      `????` properly hide secure categories
</pre>

You could imagine taking all of the expectations and mashing them into that space but then we have the same problem we had when considering the code directly.

Viewing this test as a proof suggests that each of these expectations about `CategoryList` behavior should be individual tests.

```ruby
describe CategoryList do
  let!(:user) { Fabricate(:user) }
  let!(:admin) { Fabricate(:admin) }

  context "security" do
    let!(:private_cat) do
      private_cat = Fabricate(:category) # private category
      Fabricate(:topic, category: private_cat)
      private_cat.set_permissions(admins: :full)
      private_cat.save
      private_cat
    end

    context "admin list" do
      subject!(:admin_list) do
        CategoryList.new(Guardian.new admin)
      end

      it "shows one secure category" do
        expect(admin_list.categories.count).to eq(2)
      end
    end

	# ... other expectations from original single test ...
  end
end
```

**Note** this change requires an extra context only because we are unable (as far as the author is aware) to define a subject explicitly any other way. One alternative might be to augment `it` so that it accepts an argument defining what the "it" is.

This is the start of the virtuous cycle. Good documentation as a secondary aim of a test suite suggests better ways to write tests. The above change result in the following output:


<pre>
   admin list
     Assuming:
       `user` exists, instance of User
       `admin` exists, instance of User
       `private_cat` exists, instance of Category
       `admin_list` exists, instance of CategoryList
     The test proves:
       `admin_list` shows one secure category
 </pre>

**Note** There's a disconnect here in that the `admin_list` is instantiated with the `admin`  but it's nearly possible to infer this by naming convention alone without the explicit dependency.

#### `let` It Alone

In this same vein sharing assumptions across tests is now much more valuable because it produce better documentation. This hopefully promotes better tests through factoring out shared assumptions:

```ruby
describe CategoryList do
  ...
  context "security" do
    it "properly hide secure categories" do
      cat = Fabricate(:category)
      Fabricate(:topic, category: cat)
      cat.set_permissions(:admins => :full)
      cat.save

      ...
    end

    it "doesn't show topics that you can't view" do
      ...
      private_cat = Fabricate(:category) # private category
      Fabricate(:topic, category: private_cat)
      private_cat.set_permissions(admins: :full)
      private_cat.save
      ...
    end
  end
end
```

These two fabricated categories are effectively identical. Moving them out of these tests into the parent context means their inclusion in the assumptions for each test's documentation and a semantic anchor in understanding multiple tests that depend on a private category.

```ruby
describe CategoryList do
  ...
  context "security" do
    let!(:private_cat) do
      private_cat = Fabricate(:category) # private category
      Fabricate(:topic, category: private_cat)
      private_cat.set_permissions(admins: :full)
      private_cat.save
      private_cat
    end

    it "properly hide secure categories" do ... end
    it "doesn't show topics that you can't view" do ... end
  end
end
```

As a result the documentation can reference `private_cat` directly in both cases as the same object, sharing understanding between proofs.

## Implementation

The implementation leverages Ruby, RSpec (test library/DSL), Mocha (mocking library/DSL) and the ideas were tested with a small subset of the Discourse test suite. Currently the output is generated using a small patch to the DSLs of both RSpec and Mocha to collect assumptions and the test subject. The RSpec documentation formatter was also modified to format the output.

Making the modifications to the DSL was quite awkward and time consuming, in that the context when the methods are executed is not clear. Eventually the collected assumptions were stored in a global singleton and replayed before the test output. Also, the observant reader will have noted that all the `let!` and `subject!` calls are of the `!` variant which runs the passed in block before every test. The standard `let ` and `subject` memoize the results. Using the former made the process implementation easier since each assumption and subject was recorded before every test every time.

It's not hard to imagine a similar thing working for the JavaScript testing library [Jasmine](http://jasmine.github.io/2.3/introduction.html) which uses a very similar DSL and set of testing idioms.

## Discussion

We made two attempts to design output from the tests by hand.

The first was a nearly direct translation of the tests rewriting them using an english translation of the RSpect DSL. The hope was that there were enough common assumptions and that they would be clear enough in context to be of value by themselves. As noted, even though the DSL helps with readability the code is still crowded with details required for execution. In some cases this is brutally expensive in terms of documentation:

<pre>
CategoryList
   under the assumptions:
   - a user exists
   - a admin exists
   - a new category list created with a new guardian created with a new user exists

   in the context of "security"
    under the proof specific assumptions:
    - a category `cat` exists
    - a topic exists with the category `cat`
    - `cat` was sent `set_permissions` with `:admins => :full`
    - `cat` was sent `save`

    it can be shown that:
    - a new CategoryList created with a new Guardian created with the admin sent categories sent count will have a value equal to 2
    - a new CategoryList created with a new Guardian created with the user sent categories sent count will have a value equal to 2
    - a new CategoryList created with a new Guardian created with nothing sent categories sent count will have a value equal to 2

    intuitively, CategoryList can properly hide secure categories
</pre>

Initially this seemed to be a matter of refactoring the tests. Clearly there's just too much going on in the test, too many overlapping assumptions, and too detail to be of use in this format. The thought was that, if a user could annotate the relevant parts then the documentation could flow naturally from those annotations.

```ruby
describe CategoryList do
  let(:user) { Fabricate(:user) }
  let(:admin) { Fabricate(:admin) }

  context "security" do
    let(:private_cat) do ... end

    it "properly hide secure categories" do
      admin_list = CategoryList.new(Guardian.new admin).categories
      user_list = CategoryList.new(Guardian.new user).categories
      nil_list = CategoryList.new(Guardian.new nil).categories

      prove do
        expect(admin_list.count).to eq(2)
        expect(user_list.count).to eq(0)
        expect(nil_list.count).to eq(0)
      end
    end
  end
end
```

Here `prove` splits out the test specific book keeping from the property we're trying to prove, but again this falls short of the goal. We still need some notion of the `admin_list`, `user_list`, and `nil_list` for the documentation generated from the `expect` statements to make any sense. If they don't appear in the assumptions then context is lost.

The final approach was simply to start hacking.

A nice side effect of the partially implemented approach was the realization that the test descriptions (the strings passed to the `it` method  calls) prepended with a subject from the assumptions *should* be enough along with the assumptions to get proof-like documentation out of the tests. This constraint "forces" the user to work toward very small test bodies and more focused tests (the virtuous cycle).

In the end a minimal approach for the documentation was good for the reader because it has a better signal to noise ratio and it's good for the writer because they are encouraged to minimize test bodies and maintain their tests for the purpose of documentation.

### Challenges

There are a few outstanding issues.

Primary amongst them is that there are frequently tests that are seemingly valuable that don't play well with the proof-like format of the documentation:

<pre>
ComposerMessagesFinder
  delegates work
    Assuming:
      `user` exists, instance of User
      `finder` exists, instance of ComposerMessagesFinder
      `finder`, sent `check_education_message`
      `finder`, sent `check_new_user_many_replies`
      `finder`, sent `check_avatar_notification`
      `finder`, sent `check_sequential_replies`
      `finder`, sent `check_dominating_topic`
      `finder`, sent `check_reviving_old_topic`
    The test proves:
      `finder` calls all the message finders
</pre>

Here, the expectation of method calls are the actual tests and the `finder` is send `find`. It's certainly reasonable to see this is a broken or awkward test but it's also clear that some work with the DSL could make even this an approachable bit of documentation.

Otherwise the issues with this approach are mostly as outlined above.

It requires hard work on building tests for documentation purposes which is often a non-starter for most people. The RSpec DSL already does most of the heavy lifting and not all languages support this type of BDD style testing framework. Finally, it's likely that there are much ugly corner cases lurking somewhere in the tests suite that just haven't been examined.

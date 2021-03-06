require File.dirname(__FILE__) + '/helper'

class TestStatus < Test::Unit::TestCase
  def in_temp_repo
    filename = "git_test#{Time.now.to_i.to_s}#{rand(300).to_s.rjust(3, '0')}"
    tmp_path = File.join("/tmp/", filename)

    repo = Grit::Repo.init(tmp_path)
    repo.commit_index('Empty inital commit.', :allow_empty => true)

    Dir.chdir tmp_path do # for new_file() to work correctly
      yield repo
    end

    FileUtils.rm_r(tmp_path)
  end

  def new_file(name, contents)
    File.open(name, 'w') do |f|
      f.print contents
    end
  end

  def test_invocations
    Git.any_instance.expects(:ls_files).with(:stage => true).returns('')
    Git.any_instance.expects(:ls_files).with(:others => true).returns('')
    Git.any_instance.expects(:ls_files).with(:others => true, :ignored => true, :exclude_standard => true).returns('')
    Git.any_instance.expects(:diff_index).with({}, 'HEAD').returns('')
    Git.any_instance.expects(:diff_files).with().returns('')

    in_temp_repo do |r|
      assert_not_nil(r.status)
    end
  end

  def test_new_file_has_status
    in_temp_repo do |g|
      new_file('untracked.txt', "foo\nbar\nbaz\n")

      assert_not_nil(g.status['untracked.txt'])
    end
  end

  def test_new_file_is_untracked
    in_temp_repo do |g|
      new_file('untracked.txt', "foo\nbar\nbaz\n")
      s = g.status['untracked.txt']

      assert(s.untracked?)
      assert_equal(:untracked, s.status)
    end
  end

  def test_new_file_is_unstaged
    in_temp_repo do |g|
      new_file('untracked.txt', "foo\nbar\nbaz\n")
      s = g.status['untracked.txt']

      assert(!s.changes_staged?)
      assert(s.changes_unstaged?)
    end
  end

  def test_new_file_default_blob_is_file_blob
    in_temp_repo do |g|
      new_file('untracked.txt', "foo\nbar\nbaz\n")

      assert_equal(g.status['untracked.txt'].blob(:file), g.status['untracked.txt'].blob)
    end
  end

  def test_new_file_file_blob_is_correct
    in_temp_repo do |g|
      new_file('untracked.txt', "foo\nbar\nbaz\n")

      assert_equal("foo\nbar\nbaz\n", g.status['untracked.txt'].blob(:file))
    end
  end

  def test_new_file_index_blob_is_empty
    in_temp_repo do |g|
      new_file('untracked.txt', "foo\nbar\nbaz\n")

      assert_nil(g.status['untracked.txt'].blob(:index))
    end
  end

  def test_new_file_repo_blob_is_empty
    in_temp_repo do |g|
      new_file('untracked.txt', "foo\nbar\nbaz\n")

      assert_nil(g.status['untracked.txt'].blob(:repo))
    end
  end

  def test_new_file_has_no_diff
    in_temp_repo do |g|
      new_file('untracked.txt', "foo\nbar\nbaz\n")
      s = g.status['untracked.txt']

      assert_nil(s.diff)
    end
  end

  def test_newly_added_file_has_status
    in_temp_repo do |g|
      new_file('newly_added.txt', "foo\nbar\nbaz\n")
      g.stage_files('newly_added.txt')

      assert_not_nil(g.status['newly_added.txt'])
    end
  end

  def test_newly_added_file_is_added
    in_temp_repo do |g|
      new_file('newly_added.txt', "foo\nbar\nbaz\n")
      g.stage_files('newly_added.txt')

      s = g.status['newly_added.txt']

      assert(s.added?)
      assert_equal(:added, s.status)
    end
  end

  def test_newly_added_file_is_staged
    in_temp_repo do |g|
      new_file('newly_added.txt', "foo\nbar\nbaz\n")
      g.stage_files('newly_added.txt')

      s = g.status['newly_added.txt']

      assert(s.changes_staged?)
      assert(!s.changes_unstaged?)
    end
  end

  def test_newly_added_file_default_blob_is_index_blob
    in_temp_repo do |g|
      new_file('newly_added.txt', "foo\nbar\nbaz\n")
      g.stage_files('newly_added.txt')

      assert_equal(g.status['newly_added.txt'].blob(:index).data, g.status['newly_added.txt'].blob.data)
    end
  end

  def test_newly_added_file_file_blob_is_correct
    in_temp_repo do |g|
      new_file('newly_added.txt', "foo\nbar\nbaz\n")
      g.stage_files('newly_added.txt')

      assert_equal("foo\nbar\nbaz\n", g.status['newly_added.txt'].blob(:file))
    end
  end

  def test_newly_added_file_index_blob_is_correct
    in_temp_repo do |g|
      new_file('newly_added.txt', "foo\nbar\nbaz\n")
      g.stage_files('newly_added.txt')

      assert_equal("foo\nbar\nbaz\n", g.status['newly_added.txt'].blob(:index).data)
    end
  end

  def test_newly_added_file_repo_blob_is_empty
    in_temp_repo do |g|
      new_file('newly_added.txt', "foo\nbar\nbaz\n")
      g.stage_files('newly_added.txt')

      assert_nil(g.status['newly_added.txt'].blob(:repo))
    end
  end

  def test_newly_added_file_diff_is_correct
    in_temp_repo do |g|
      new_file('newly_added.txt', "foo\nbar\nbaz\n")
      g.stage_files('newly_added.txt')

      d = g.status['newly_added.txt'].diff

      assert_not_nil(d)
      assert_equal('newly_added.txt', d.a_path)
      assert_equal('newly_added.txt', d.b_path)
      assert(d.new_file)
      assert(!d.deleted_file)
      assert_nil(d.a_sha)
      assert_equal('86e041d', d.b_sha)
      assert_equal("--- /dev/null\n+++ b/newly_added.txt\n@@ -0,0 +1,3 @@\n+foo\n+bar\n+baz\n", d.diff)
    end
  end

  def test_modified_file_has_status
    in_temp_repo do |g|
      new_file('modified.txt', "foo\nbar")
      g.stage_files('modified.txt')
      g.commit_index("Committed file to be modified.")
      new_file('modified.txt', "foo\nbar\nbaz\n")

      assert_not_nil(g.status['modified.txt'])
    end
  end

  def test_modified_file_is_modified
    in_temp_repo do |g|
      new_file('modified.txt', "foo\nbar")
      g.stage_files('modified.txt')
      g.commit_index("Committed file to be modified.")
      new_file('modified.txt', "foo\nbar\nbaz\n")

      s = g.status['modified.txt']

      assert(s.modified?)
      assert_equal(:modified, s.status)
    end
  end

  def test_modified_file_is_unstaged
    in_temp_repo do |g|
      new_file('modified.txt', "foo\nbar")
      g.stage_files('modified.txt')
      g.commit_index("Committed file to be modified.")
      new_file('modified.txt', "foo\nbar\nbaz\n")

      s = g.status['modified.txt']

      assert(!s.changes_staged?)
      assert(s.changes_unstaged?)
    end
  end

  def test_modified_file_default_blob_is_file_blob
    in_temp_repo do |g|
      new_file('modified.txt', "foo\nbar")
      g.stage_files('modified.txt')
      g.commit_index("Committed file to be modified.")
      new_file('modified.txt', "foo\nbar\nbaz\n")

      assert_equal(g.status['modified.txt'].blob(:file), g.status['modified.txt'].blob)
    end
  end

  def test_modified_file_file_blob_is_correct
    in_temp_repo do |g|
      new_file('modified.txt', "foo\nbar")
      g.stage_files('modified.txt')
      g.commit_index("Committed file to be modified.")
      new_file('modified.txt', "foo\nbar\nbaz\n")

      assert_equal("foo\nbar\nbaz\n", g.status['modified.txt'].blob(:file))
    end
  end

  def test_modified_file_index_blob_is_correct
    in_temp_repo do |g|
      new_file('modified.txt', "foo\nbar")
      g.stage_files('modified.txt')
      g.commit_index("Committed file to be modified.")
      new_file('modified.txt', "foo\nbar\nbaz\n")

      assert_equal("foo\nbar", g.status['modified.txt'].blob(:index).data)
    end
  end

  def test_modified_file_repo_blob_is_correct
    in_temp_repo do |g|
      new_file('modified.txt', "foo\nbar")
      g.stage_files('modified.txt')
      g.commit_index("Committed file to be modified.")
      new_file('modified.txt', "foo\nbar\nbaz\n")

      assert_equal("foo\nbar", g.status['modified.txt'].blob(:repo).data)
    end
  end

  def test_modified_file_uncached_diff_is_correct
    in_temp_repo do |g|
      new_file('modified.txt', "foo\nbar")
      g.stage_files('modified.txt')
      g.commit_index("Committed file to be modified.")
      new_file('modified.txt', "foo\nbar\nbaz\n")

      d = g.status['modified.txt'].diff

      assert_not_nil(d)
      assert_equal('modified.txt', d.a_path)
      assert_equal('modified.txt', d.b_path)
      assert(!d.new_file)
      assert(!d.deleted_file)
      assert_equal('a907ec3', d.a_sha)
      assert_equal('86e041d', d.b_sha)
      assert_equal("--- a/modified.txt\n+++ b/modified.txt\n@@ -1,2 +1,3 @@\n foo\n-bar\n\\ No newline at end of file\n+bar\n+baz\n", d.diff)
    end
  end

  def test_updated_file_has_status
    in_temp_repo do |g|
      new_file('updated.txt', "foo\nbar")
      g.stage_files('updated.txt')
      g.commit_index("Committed file to be modified.")
      new_file('updated.txt', "foo\nbar\nbaz\n")
      g.stage_files('updated.txt')

      assert_not_nil(g.status['updated.txt'])
    end
  end

  def test_updated_file_is_modified
    in_temp_repo do |g|
      new_file('updated.txt', "foo\nbar")
      g.stage_files('updated.txt')
      g.commit_index("Committed file to be modified.")
      new_file('updated.txt', "foo\nbar\nbaz\n")
      g.stage_files('updated.txt')

      s = g.status['updated.txt']

      assert(s.modified?)
      assert_equal(:modified, s.status)
    end
  end

  def test_updated_file_is_staged
    in_temp_repo do |g|
      new_file('updated.txt', "foo\nbar")
      g.stage_files('updated.txt')
      g.commit_index("Committed file to be modified.")
      new_file('updated.txt', "foo\nbar\nbaz\n")
      g.stage_files('updated.txt')

      s = g.status['updated.txt']

      assert(s.changes_staged?)
      assert(!s.changes_unstaged?)
    end
  end

  def test_updated_file_default_blob_is_index_blob
    in_temp_repo do |g|
      new_file('updated.txt', "foo\nbar")
      g.stage_files('updated.txt')
      g.commit_index("Committed file to be modified.")
      new_file('updated.txt', "foo\nbar\nbaz\n")
      g.stage_files('updated.txt')

      assert_equal(g.status['updated.txt'].blob(:index).data, g.status['updated.txt'].blob.data)
    end
  end

  def test_updated_file_file_blob_is_correct
    in_temp_repo do |g|
      new_file('updated.txt', "foo\nbar")
      g.stage_files('updated.txt')
      g.commit_index("Committed file to be modified.")
      new_file('updated.txt', "foo\nbar\nbaz\n")
      g.stage_files('updated.txt')

      assert_equal("foo\nbar\nbaz\n", g.status['updated.txt'].blob(:file))
    end
  end

  def test_updated_file_index_blob_is_correct
    in_temp_repo do |g|
      new_file('updated.txt', "foo\nbar")
      g.stage_files('updated.txt')
      g.commit_index("Committed file to be modified.")
      new_file('updated.txt', "foo\nbar\nbaz\n")
      g.stage_files('updated.txt')

      assert_equal("foo\nbar\nbaz\n", g.status['updated.txt'].blob(:index).data)
    end
  end

  def test_updated_file_repo_blob_is_correct
    in_temp_repo do |g|
      new_file('updated.txt', "foo\nbar")
      g.stage_files('updated.txt')
      g.commit_index("Committed file to be modified.")
      new_file('updated.txt', "foo\nbar\nbaz\n")
      g.stage_files('updated.txt')

      assert_equal("foo\nbar", g.status['updated.txt'].blob(:repo).data)
    end
  end

  def test_updated_file_diff_is_correct
    in_temp_repo do |g|
      new_file('updated.txt', "foo\nbar")
      g.stage_files('updated.txt')
      g.commit_index("Committed file to be modified.")
      new_file('updated.txt', "foo\nbar\nbaz\n")
      g.stage_files('updated.txt')

      d = g.status['updated.txt'].diff

      assert_not_nil(d)
      assert_equal('updated.txt', d.a_path)
      assert_equal('updated.txt', d.b_path)
      assert(!d.new_file)
      assert(!d.deleted_file)
      assert_equal('a907ec3', d.a_sha)
      assert_equal('86e041d', d.b_sha)
      assert_equal("--- a/updated.txt\n+++ b/updated.txt\n@@ -1,2 +1,3 @@\n foo\n-bar\n\\ No newline at end of file\n+bar\n+baz\n", d.diff)
    end
  end

  def test_removed_file_has_status
    in_temp_repo do |g|
      new_file('removed.txt', "foo\nbar\nbaz\n")
      g.stage_files('removed.txt')
      g.commit_index("Added file to be deleted.")
      g.remove('removed.txt') # also stages the changes

      assert_not_nil(g.status['removed.txt'])
    end
  end

  def test_removed_file_is_deleted
    in_temp_repo do |g|
      new_file('removed.txt', "foo\nbar\nbaz\n")
      g.stage_files('removed.txt')
      g.commit_index("Added file to be deleted.")
      g.remove('removed.txt') # also stages the changes

      s = g.status['removed.txt']

      assert(s.deleted?)
      assert_equal(:deleted, s.status)
    end
  end

  def test_removed_file_is_staged
    in_temp_repo do |g|
      new_file('removed.txt', "foo\nbar\nbaz\n")
      g.stage_files('removed.txt')
      g.commit_index("Added file to be deleted.")
      g.remove('removed.txt') # also stages the changes

      s = g.status['removed.txt']

      assert(s.changes_staged?)
      assert(!s.changes_unstaged?)
    end
  end

  def test_removed_file_default_blob_is_index_blob
    in_temp_repo do |g|
      new_file('removed.txt', "foo\nbar\nbaz\n")
      g.stage_files('removed.txt')
      g.commit_index("Added file to be deleted.")
      g.remove('removed.txt') # also stages the changes

      assert_equal(g.status['removed.txt'].blob(:index), g.status['removed.txt'].blob)
    end
  end

  def test_removed_file_file_blob_is_empty
    in_temp_repo do |g|
      new_file('removed.txt', "foo\nbar\nbaz\n")
      g.stage_files('removed.txt')
      g.commit_index("Added file to be deleted.")
      g.remove('removed.txt') # also stages the changes

      assert_nil(g.status['removed.txt'].blob(:file))
    end
  end

  def test_removed_file_index_blob_is_empty
    in_temp_repo do |g|
      new_file('removed.txt', "foo\nbar\nbaz\n")
      g.stage_files('removed.txt')
      g.commit_index("Added file to be deleted.")
      g.remove('removed.txt') # also stages the changes

      assert_nil(g.status['removed.txt'].blob(:index))
    end
  end

  def test_removed_file_repo_blob_is_correct
    in_temp_repo do |g|
      new_file('removed.txt', "foo\nbar\nbaz\n")
      g.stage_files('removed.txt')
      g.commit_index("Added file to be deleted.")
      g.remove('removed.txt') # also stages the changes

      assert_equal("foo\nbar\nbaz\n", g.status['removed.txt'].blob(:repo).data)
    end
  end

  def test_removed_file_diff_is_correct
    in_temp_repo do |g|
      new_file('removed.txt', "foo\nbar\nbaz\n")
      g.stage_files('removed.txt')
      g.commit_index("Added file to be deleted.")
      g.remove('removed.txt') # also stages the changes

      d = g.status['removed.txt'].diff

      assert_not_nil(d)
      assert_equal('removed.txt', d.a_path)
      assert_equal('removed.txt', d.b_path)
      assert(!d.new_file)
      assert(d.deleted_file)
      assert_equal('86e041d', d.a_sha)
      assert_nil(d.b_sha)
      assert_equal("--- a/removed.txt\n+++ /dev/null\n@@ -1,3 +0,0 @@\n-foo\n-bar\n-baz\n", d.diff)
    end
  end

  def test_deleted_file_has_status
    in_temp_repo do |g|
      new_file('deleted.txt', "foo\nbar\nbaz\n")
      g.stage_files('deleted.txt')
      g.commit_index("Added file to be deleted.")
      FileUtils.rm('deleted.txt')

      assert_not_nil(g.status['deleted.txt'])
    end
  end

  def test_deleted_file_is_deleted
    in_temp_repo do |g|
      new_file('deleted.txt', "foo\nbar\nbaz\n")
      g.stage_files('deleted.txt')
      g.commit_index("Added file to be deleted.")
      FileUtils.rm('deleted.txt')

      s = g.status['deleted.txt']

      assert(s.deleted?)
      assert_equal(:deleted, s.status)
    end
  end

  def test_deleted_file_is_unstaged
    in_temp_repo do |g|
      new_file('deleted.txt', "foo\nbar\nbaz\n")
      g.stage_files('deleted.txt')
      g.commit_index("Added file to be deleted.")
      FileUtils.rm('deleted.txt')

      s = g.status['deleted.txt']

      assert(!s.changes_staged?)
      assert(s.changes_unstaged?)
    end
  end

  def test_deleted_file_default_blob_is_file_blob
    in_temp_repo do |g|
      new_file('deleted.txt', "foo\nbar\nbaz\n")
      g.stage_files('deleted.txt')
      g.commit_index("Added file to be deleted.")
      FileUtils.rm('deleted.txt')

      assert_equal(g.status['deleted.txt'].blob(:file), g.status['deleted.txt'].blob)
    end
  end

  def test_deleted_file_file_blob_is_empty
    in_temp_repo do |g|
      new_file('deleted.txt', "foo\nbar\nbaz\n")
      g.stage_files('deleted.txt')
      g.commit_index("Added file to be deleted.")
      FileUtils.rm('deleted.txt')

      assert_nil(g.status['deleted.txt'].blob(:file))
    end
  end

  def test_deleted_file_index_blob_is_correct
    in_temp_repo do |g|
      new_file('deleted.txt', "foo\nbar\nbaz\n")
      g.stage_files('deleted.txt')
      g.commit_index("Added file to be deleted.")
      FileUtils.rm('deleted.txt')

      assert_equal("foo\nbar\nbaz\n", g.status['deleted.txt'].blob(:index).data)
    end
  end

  def test_deleted_file_repo_blob_is_correct
    in_temp_repo do |g|
      new_file('deleted.txt', "foo\nbar\nbaz\n")
      g.stage_files('deleted.txt')
      g.commit_index("Added file to be deleted.")
      FileUtils.rm('deleted.txt')

      assert_equal("foo\nbar\nbaz\n", g.status['deleted.txt'].blob(:repo).data)
    end
  end

  def test_deleted_file_diff_is_correct
    in_temp_repo do |g|
      new_file('deleted.txt', "foo\nbar\nbaz\n")
      g.stage_files('deleted.txt')
      g.commit_index("Added file to be deleted.")
      FileUtils.rm('deleted.txt')

      d = g.status['deleted.txt'].diff

      assert_not_nil(d)
      assert_equal('deleted.txt', d.a_path)
      assert_equal('deleted.txt', d.b_path)
      assert(!d.new_file)
      assert(d.deleted_file)
      assert_equal('86e041d', d.a_sha)
      assert_nil(d.b_sha)
      assert_equal("--- a/deleted.txt\n+++ /dev/null\n@@ -1,3 +0,0 @@\n-foo\n-bar\n-baz\n", d.diff)
    end
  end

  def test_remodified_file_has_status
    in_temp_repo do |g|
      new_file('remodified.txt', "foo")
      g.stage_files('remodified.txt')
      g.commit_index("Committed file to be modified.")
      new_file('remodified.txt', "foo\nbar\n")
      g.stage_files('remodified.txt')
      new_file('remodified.txt', "foo\nbar\nbaz\n")

      s = g.status['remodified.txt']

      assert_not_nil(s)
      assert_kind_of(Array, s)
      assert_equal(2, s.size)
    end
  end

  def test_remodified_file_is_modified
    in_temp_repo do |g|
      new_file('remodified.txt', "foo")
      g.stage_files('remodified.txt')
      g.commit_index("Committed file to be modified.")
      new_file('remodified.txt', "foo\nbar\n")
      g.stage_files('remodified.txt')
      new_file('remodified.txt', "foo\nbar\nbaz\n")

      s = g.status['remodified.txt']

      assert(s.all?(&:modified?))
    end
  end

  def test_remodified_file_is_staged_and_unstaged
    in_temp_repo do |g|
      new_file('remodified.txt', "foo")
      g.stage_files('remodified.txt')
      g.commit_index("Committed file to be modified.")
      new_file('remodified.txt', "foo\nbar\n")
      g.stage_files('remodified.txt')
      new_file('remodified.txt', "foo\nbar\nbaz\n")

      s = g.status['remodified.txt']

      assert(s.any?(&:changes_staged?))
      assert(s.any?(&:changes_unstaged?))
    end
  end

  def test_unstaged_remodified_file_blobs_are_correct
    in_temp_repo do |g|
      new_file('remodified.txt', "foo")
      g.stage_files('remodified.txt')
      g.commit_index("Committed file to be modified.")
      new_file('remodified.txt', "foo\nbar\n")
      g.stage_files('remodified.txt')
      new_file('remodified.txt', "foo\nbar\nbaz\n")

      s = g.status['remodified.txt'].select(&:changes_unstaged?).first

      assert_equal(s.blob(:file), s.blob)
      assert_equal("foo\nbar\nbaz\n", s.blob(:file))
      assert_equal("foo\nbar\n", s.blob(:index).data)
      assert_equal("foo\nbar\n", s.blob(:repo).data)
    end
  end

  def test_staged_remodified_file_blobs_are_correct
    in_temp_repo do |g|
      new_file('remodified.txt', "foo")
      g.stage_files('remodified.txt')
      g.commit_index("Committed file to be modified.")
      new_file('remodified.txt', "foo\nbar\n")
      g.stage_files('remodified.txt')
      new_file('remodified.txt', "foo\nbar\nbaz\n")

      s = g.status['remodified.txt'].select(&:changes_staged?).first

      assert_equal(s.blob(:index), s.blob)
      assert_equal("foo\nbar\nbaz\n", s.blob(:file))
      assert_nil(s.blob(:index))
      assert_equal("foo", s.blob(:repo).data)
    end
  end

  def test_unstaged_remodified_file_diff_is_correct
    in_temp_repo do |g|
      new_file('remodified.txt', "foo")
      g.stage_files('remodified.txt')
      g.commit_index("Committed file to be modified.")
      new_file('remodified.txt', "foo\nbar\n")
      g.stage_files('remodified.txt')
      new_file('remodified.txt', "foo\nbar\nbaz\n")

      s = g.status['remodified.txt'].select(&:changes_unstaged?).first
      d = s.diff

      assert_not_nil(d)
      assert_equal('remodified.txt', d.a_path)
      assert_equal('remodified.txt', d.b_path)
      assert(!d.new_file)
      assert(!d.deleted_file)
      assert_equal('3bd1f0e', d.a_sha)
      assert_equal('86e041d', d.b_sha)
      assert_equal("--- a/remodified.txt\n+++ b/remodified.txt\n@@ -1,2 +1,3 @@\n foo\n bar\n+baz\n", d.diff)
    end
  end

  def test_staged_remodified_file_diff_is_correct
    in_temp_repo do |g|
      new_file('remodified.txt', "foo")
      g.stage_files('remodified.txt')
      g.commit_index("Committed file to be modified.")
      new_file('remodified.txt', "foo\nbar\n")
      g.stage_files('remodified.txt')
      new_file('remodified.txt', "foo\nbar\nbaz\n")

      s = g.status['remodified.txt'].select(&:changes_staged?).first
      d = s.diff

      assert_not_nil(d)
      assert_equal('remodified.txt', d.a_path)
      assert_equal('remodified.txt', d.b_path)
      assert(!d.new_file)
      assert(!d.deleted_file)
      assert_equal('1910281', d.a_sha)
      assert_equal('3bd1f0e', d.b_sha)
      assert_equal("--- a/remodified.txt\n+++ b/remodified.txt\n@@ -1 +1,2 @@\n-foo\n\\ No newline at end of file\n+foo\n+bar\n", d.diff)
    end
  end

  def test_modified_added_file_has_status
    in_temp_repo do |g|
      new_file('modified_added.txt', "foo")
      g.stage_files('modified_added.txt')
      new_file('modified_added.txt', "foo\nbar\n")

      s = g.status['modified_added.txt']

      assert_not_nil(s)
      assert_kind_of(Array, s)
      assert_equal(2, s.size)
    end
  end

  def test_modified_added_file_is_added_and_modified
    in_temp_repo do |g|
      new_file('modified_added.txt', "foo")
      g.stage_files('modified_added.txt')
      new_file('modified_added.txt', "foo\nbar\n")

      s = g.status['modified_added.txt']

      assert(s.any?(&:added?))
      assert(s.any?(&:modified?))
    end
  end

  def test_modified_added_file_is_staged_and_unstaged
    in_temp_repo do |g|
      new_file('modified_added.txt', "foo")
      g.stage_files('modified_added.txt')
      new_file('modified_added.txt', "foo\nbar\n")

      s = g.status['modified_added.txt']

      assert(s.any?(&:changes_staged?))
      assert(s.any?(&:changes_unstaged?))
    end
  end

  def test_unstaged_modified_added_file_blobs_are_correct
    in_temp_repo do |g|
      new_file('modified_added.txt', "foo")
      g.stage_files('modified_added.txt')
      new_file('modified_added.txt', "foo\nbar\n")

      s = g.status['modified_added.txt'].select(&:changes_unstaged?).first

      assert_equal(s.blob(:file), s.blob)
      assert_equal("foo\nbar\n", s.blob(:file))
      assert_equal("foo", s.blob(:index).data)
      assert_equal("foo", s.blob(:repo).data)
    end
  end

  def test_staged_modified_added_file_blobs_are_correct
    in_temp_repo do |g|
      new_file('modified_added.txt', "foo")
      g.stage_files('modified_added.txt')
      new_file('modified_added.txt', "foo\nbar\n")

      s = g.status['modified_added.txt'].select(&:changes_staged?).first

      assert_equal(s.blob(:index), s.blob)
      assert_equal("foo\nbar\n", s.blob(:file))
      assert_nil(s.blob(:index))
      assert_nil(s.blob(:repo))
    end
  end

  def test_unstaged_modified_added_file_diff_is_correct
    in_temp_repo do |g|
      new_file('modified_added.txt', "foo")
      g.stage_files('modified_added.txt')
      new_file('modified_added.txt', "foo\nbar\n")

      s = g.status['modified_added.txt'].select(&:changes_unstaged?).first
      d = s.diff

      assert_not_nil(d)
      assert_equal('modified_added.txt', d.a_path)
      assert_equal('modified_added.txt', d.b_path)
      assert(!d.new_file)
      assert(!d.deleted_file)
      assert_equal('1910281', d.a_sha)
      assert_equal('3bd1f0e', d.b_sha)
      assert_equal("--- a/modified_added.txt\n+++ b/modified_added.txt\n@@ -1 +1,2 @@\n-foo\n\\ No newline at end of file\n+foo\n+bar\n", d.diff)
    end
  end

  def test_staged_modified_added_file_diff_is_correct
    in_temp_repo do |g|
      new_file('modified_added.txt', "foo")
      g.stage_files('modified_added.txt')
      new_file('modified_added.txt', "foo\nbar\n")

      s = g.status['modified_added.txt'].select(&:changes_staged?).first
      d = s.diff

      assert_not_nil(d)
      assert_equal('modified_added.txt', d.a_path)
      assert_equal('modified_added.txt', d.b_path)
      assert(d.new_file)
      assert(!d.deleted_file)
      assert_nil(d.a_sha)
      assert_equal('1910281', d.b_sha)
      assert_equal("--- /dev/null\n+++ b/modified_added.txt\n@@ -0,0 +1 @@\n+foo\n\\ No newline at end of file\n", d.diff)
    end
  end
end

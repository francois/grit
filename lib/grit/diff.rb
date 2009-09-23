    attr_reader :a_sha,  :b_sha
    def initialize(repo, a_path, b_path, a_sha, b_sha, a_mode, b_mode, new_file, deleted_file, diff)
      @a_sha  = a_sha =~ /^0*$/ ? nil : a_sha
      @b_sha  = b_sha =~ /^0*$/ ? nil : b_sha
      @a_blob = @a_sha.nil? ? nil : Blob.create(repo, :id => @a_sha)
      @b_blob = @b_sha.nil? ? nil : Blob.create(repo, :id => @b_sha)
      lines = text.split("\n", -1)
        m, a_sha, b_sha, b_mode = *lines.shift.match(%r{^index ([0-9A-Fa-f]+)\.\.([0-9A-Fa-f]+) ?(.+)?$})
        diff = nil if diff.empty?
        diffs << Diff.new(repo, a_path, b_path, a_sha, b_sha, a_mode, b_mode, new_file, deleted_file, diff)

    # Tells you the number of deleted lines in the diff.
    def deletions
      # -1 for the line starting in ---
      self.diff.split("\n").count { |line| line.start_with?('-') } -1
    end

    # Tells you the number of inserted lines in the diff.
    def insertions
      # -1 for the line starting in +++
      self.diff.split("\n").count { |line| line.start_with?('+') } -1
    end
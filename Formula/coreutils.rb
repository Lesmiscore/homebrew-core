class Coreutils < Formula
  desc "GNU File, Shell, and Text utilities"
  homepage "https://www.gnu.org/software/coreutils"
  url "https://ftp.gnu.org/gnu/coreutils/coreutils-8.29.tar.xz"
  mirror "https://ftpmirror.gnu.org/coreutils/coreutils-8.29.tar.xz"
  sha256 "92d0fa1c311cacefa89853bdb53c62f4110cdfda3820346b59cbd098f40f955e"

  bottle do
    sha256 "20e12e8aaa50778db12accc12fc2ae5e29cdd58988064dbc912bcfb10a106272" => :high_sierra
    sha256 "83cb185057a6add9b9289504801240f33020494c4b85af07272a85050cd99f65" => :sierra
    sha256 "0c25b2cebfd54bf325360b6ab566df78a6711f5526fd44fc244558748bd27475" => :el_capitan
    sha256 "0fc8eabba9ff7dd137ae3754a33f0e97514ecd518fdd8e8224af4073a9b7f013" => :x86_64_linux
  end

  # --default-names interferes with Mac builds.
  option "with-default-names", "Do not prepend 'g' to the binary" if OS.linux?
  deprecated_option "default-names" => "with-default-names"

  head do
    url "https://git.savannah.gnu.org/git/coreutils.git"

    depends_on "autoconf" => :build
    depends_on "automake" => :build
    depends_on "bison" => :build
    depends_on "gettext" => :build
    depends_on "texinfo" => :build
    depends_on "xz" => :build
    depends_on "wget" => :build
    depends_on "gperf" => :build unless OS.mac?
  end

  depends_on "gmp" => :optional

  conflicts_with "ganglia", :because => "both install `gstat` binaries"
  conflicts_with "gegl", :because => "both install `gcut` binaries"
  conflicts_with "idutils", :because => "both install `gid` and `gid.1`"
  conflicts_with "aardvark_shell_utils", :because => "both install `realpath` binaries"

  def install
    if MacOS.version == :el_capitan
      # Work around unremovable, nested dirs bug that affects lots of
      # GNU projects. See:
      # https://github.com/Homebrew/homebrew/issues/45273
      # https://github.com/Homebrew/homebrew/issues/44993
      # This is thought to be an el_capitan bug:
      # https://lists.gnu.org/archive/html/bug-tar/2015-10/msg00017.html
      ENV["gl_cv_func_getcwd_abort_bug"] = "no"

      # renameatx_np and RENAME_EXCL are available at compile time from Xcode 8
      # (10.12 SDK), but the former is not available at runtime.
      inreplace "lib/renameat2.c", "defined RENAME_EXCL", "defined UNDEFINED_GIBBERISH"
    end

    system "./bootstrap" if build.head?

    args = %W[
      --prefix=#{prefix}
      --program-prefix=g
    ]
    args << "--without-gmp" if build.without? "gmp"
    system "./configure", *args
    system "make", "install"

    # Symlink all commands into libexec/gnubin without the 'g' prefix
    coreutils_filenames(bin).each do |cmd|
      (libexec/"gnubin").install_symlink bin/"g#{cmd}" => cmd
    end
    # Symlink all man(1) pages into libexec/gnuman without the 'g' prefix
    coreutils_filenames(man1).each do |cmd|
      (libexec/"gnuman"/"man1").install_symlink man1/"g#{cmd}" => cmd
    end

    if build.with? "default-names"
      # Symlink all commands without the 'g' prefix
      coreutils_filenames(bin).each do |cmd|
        bin.install_symlink "g#{cmd}" => cmd
      end
      # Symlink all man(1) pages without the 'g' prefix
      coreutils_filenames(man1).each do |cmd|
        man1.install_symlink "g#{cmd}" => cmd
      end
    else
      # Symlink non-conflicting binaries
      bin.install_symlink "grealpath" => "realpath"
      man1.install_symlink "grealpath.1" => "realpath.1"
    end
  end

  def caveats; <<~EOS
    All commands have been installed with the prefix 'g'.

    If you really need to use these commands with their normal names, you
    can add a "gnubin" directory to your PATH from your bashrc like:

        PATH="#{opt_libexec}/gnubin:$PATH"

    Additionally, you can access their man pages with normal names if you add
    the "gnuman" directory to your MANPATH from your bashrc as well:

        MANPATH="#{opt_libexec}/gnuman:$MANPATH"

    EOS
  end if build.without? "default-names"

  def coreutils_filenames(dir)
    filenames = []
    dir.find do |path|
      next if path.directory? || path.basename.to_s == ".DS_Store"
      filenames << path.basename.to_s.sub(/^g/, "")
    end
    filenames.sort
  end

  test do
    (testpath/"test").write("test")
    (testpath/"test.sha1").write("a94a8fe5ccb19ba61c4c0873d391e987982fbbd3 test")
    system bin/"gsha1sum", "-c", "test.sha1"
    system bin/"gln", "-f", "test", "test.sha1"
  end
end

class Dd4hep < Formula
  desc "Detector description toolkit for high energy physics"
  homepage "https://dd4hep.web.cern.ch/"
  url "https://github.com/AIDASoft/DD4hep/archive/refs/tags/v01-38.tar.gz"
  version "1.38.0"
  sha256 "8a11c42cfd2026faae421260bc3dea9f61c78ebacd1f9ba1b0ca3ff054425ffd"
  license "LGPL-3.0-or-later"
  revision 1

  livecheck do
    url :stable
    regex(/^v0*(\d+)[._-]0*(\d+)(?:[._-]0*(\d+))?$/i)
    strategy :github_latest do |json, regex|
      match = json["tag_name"]&.match(regex)
      next if match.blank?

      "#{match[1].to_i}.#{match[2].to_i}.#{match[3].to_i}"
    end
  end

  keg_only "its JSON headers conflict with jsoncpp on case-insensitive filesystems"

  depends_on "cmake" => [:build, :test]
  depends_on "ninja" => :build
  depends_on "boost"
  depends_on "expat"
  depends_on "paulgessinger/hep/geant4"
  depends_on "python@3.14"
  depends_on "root"
  depends_on "vdt"
  depends_on "xerces-c"
  depends_on "zlib"

  def install
    # Homebrew updates Python patch releases independently of ROOT. Keep the
    # major/minor ABI check, including for downstream CMake consumers.
    inreplace "cmake/DD4hepBuild.cmake",
              "SET(REQUIRE_PYTHON_VERSION ${ROOT_PYTHON_VERSION})",
              'string(REGEX MATCH "^[0-9]+[.][0-9]+" REQUIRE_PYTHON_VERSION "${ROOT_PYTHON_VERSION}")'

    # Upstream hardcodes lib in its install rpaths. Keep tools and plugins
    # usable with the lib/dd4hep layout without relying on shell library paths.
    inreplace "cmake/DD4hepBuild.cmake" do |s|
      s.gsub! '"@loader_path/../lib"', '"@loader_path;@loader_path/../${CMAKE_INSTALL_LIBDIR}"'
      s.gsub! '"${CMAKE_INSTALL_PREFIX}/lib"', '"${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR}"'
    end

    # dd4hep.py replaces ROOT's dynamic search path with DD4HEP_LIBRARY_PATH.
    # Include ROOT here so its dictionaries can autoload in a clean shell.
    inreplace "cmake/thisdd4hep_only.sh",
              "#----PYTHONPATH",
              <<~SH
                dd4hep_add_library_path #{formula_opt_lib("root")}/root;
                dd4hep_add_library_path #{formula_opt_lib("paulgessinger/hep/geant4")};
                dd4hep_add_path ROOT_INCLUDE_PATH #{formula_opt_prefix("paulgessinger/hep/geant4")}/include/Geant4;
                #----PYTHONPATH
              SH

    # ROOT dictionaries and clients must use the same C++ standard as ROOT.
    cxx_standard = Utils.safe_popen_read(formula_opt_bin("root")/"root-config", "--cxxstandard").strip

    # Keep ROOT dictionaries and plugin metadata beside their libraries in a
    # package subdirectory, as required by Homebrew's new-formula audit.
    system "cmake", "-S", ".", "-B", "build", "-G", "Ninja",
                    "-DCMAKE_CXX_STANDARD=#{cxx_standard}",
                    "-DROOT_DIR=#{formula_opt_prefix("root")}/share/root/cmake",
                    "-DPython_EXECUTABLE=#{formula_opt_bin("python@3.14")}/python3.14",
                    "-DDD4HEP_USE_GEANT4=ON",
                    "-DGeant4_DIR=#{formula_opt_lib("paulgessinger/hep/geant4")}/cmake/Geant4",
                    "-DDD4HEP_USE_XERCESC=OFF",
                    "-DDD4HEP_DISABLE_PACKAGES=DDCAD",
                    "-DDD4HEP_BUILD_EXAMPLES=OFF",
                    "-DBUILD_DOCS=OFF",
                    "-DBUILD_TESTING=OFF",
                    *std_cmake_args,
                    "-DCMAKE_INSTALL_LIBDIR=lib/dd4hep"
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"
  end

  def caveats
    <<~EOS
      Geant4/DDG4 simulation support is included. CAD support is not included.

      Set up DD4hep in bash or zsh before using its tools or Python bindings:
        source #{formula_opt_bin("paulgessinger/hep/geant4")}/geant4.sh
        source #{opt_bin}/thisdd4hep_only.sh

      Use Homebrew's Python 3.14 for the bindings:
        #{formula_opt_bin("python@3.14")}/python3.14 -c 'import dd4hep'

      For CMake clients, pass -DDD4hep_DIR=#{opt_prefix}/cmake.
    EOS
  end

  test do
    # Exercise XML parsing, plugin discovery, ROOT geometry and the installed
    # CMake export, rather than merely checking a tool's version string.
    (testpath/"compact.xml").write <<~XML
      <lccdd>
        <info name="HomebrewTest" title="Homebrew geometry test" author="Homebrew"
              url="https://brew.sh" status="test" version="1.0"/>
        <define>
          <constant name="world_x" value="100*cm"/>
          <constant name="world_y" value="100*cm"/>
          <constant name="world_z" value="100*cm"/>
        </define>
        <includes>
          <gdmlFile ref="#{prefix}/DDDetectors/compact/elements.xml"/>
          <gdmlFile ref="#{prefix}/DDDetectors/compact/materials.xml"/>
        </includes>
        <detectors>
          <detector id="1" name="TestBox" type="DD4hep_BoxSegment">
            <material name="Air"/>
            <box x="1*cm" y="2*cm" z="3*cm"/>
          </detector>
        </detectors>
      </lccdd>
    XML

    (testpath/"test.cpp").write <<~CPP
      #include <DD4hep/Detector.h>
      #include <DD4hep/Shapes.h>
      #include <DD4hep/DD4hepUnits.h>
      #include <cmath>
      int main() {
        auto& detector = dd4hep::Detector::getInstance();
        detector.fromCompact("compact.xml");
        const auto box = detector.detector("TestBox");
        if (!box.isValid() || box.id() != 1) return 1;
        const dd4hep::Box shape = box.volume().solid();
        return std::abs(shape.z() - 3 * dd4hep::cm) < 1e-9 ? 0 : 2;
      }
    CPP

    (testpath/"CMakeLists.txt").write <<~CMAKE
      cmake_minimum_required(VERSION 3.16)
      project(dd4hep_test LANGUAGES CXX)
      find_package(DD4hep REQUIRED CONFIG COMPONENTS DDCore DDG4)
      if(NOT DD4HEP_USE_GEANT4 OR NOT TARGET DD4hep::DDG4)
        message(FATAL_ERROR "This formula must enable Geant4/DDG4")
      endif()
      add_executable(dd4hep_test test.cpp)
      target_compile_features(dd4hep_test PRIVATE cxx_std_${DD4hep_BUILD_CXX_STANDARD})
      target_link_libraries(dd4hep_test PRIVATE DD4hep::DDCore DD4hep::DDG4)
    CMAKE

    ENV.prepend_path "DD4HEP_LIBRARY_PATH", lib/"dd4hep"
    ENV.prepend_path "ROOT_INCLUDE_PATH", include
    ENV.prepend_path "DYLD_LIBRARY_PATH", lib/"dd4hep" if OS.mac?
    ENV.prepend_path "LD_LIBRARY_PATH", lib/"dd4hep" if OS.linux?
    system "cmake", "-S", ".", "-B", "build", "-DDD4hep_DIR=#{prefix}/cmake", *std_cmake_args
    system "cmake", "--build", "build"
    system testpath/"build/dd4hep_test"

    (testpath/"test.py").write <<~PYTHON
      import dd4hep
      import ROOT
      assert ROOT.gSystem.Load("libGenVector") >= 0
      detector = dd4hep.Detector.getInstance()
      detector.fromCompact("compact.xml")
      assert detector.detector("TestBox").id() == 1
    PYTHON
    (testpath/"simulation.py").write <<~PYTHON
      import DDG4
      import ROOT
      from g4units import MeV

      kernel = DDG4.Kernel()
      kernel.loadGeometry("file:#{testpath}/compact.xml")
      simulation = DDG4.Geant4(kernel)
      kernel.UI = ""
      kernel.NumEvents = 3
      simulation.addDetectorConstruction("Geant4DetectorGeometryConstruction/Geometry")
      simulation.setupPhysics("FTFP_BERT")
      simulation.setupGun("Gun", particle="gamma", energy=MeV, isotrop=False)
      assert ROOT.gInterpreter.Declare('''
          #include <G4RunManager.hh>
          #include <G4Run.hh>
          int completed_events() {
              return G4RunManager::GetRunManager()->GetCurrentRun()->GetNumberOfEvent();
          }
      ''')
      assert kernel.configure()
      assert kernel.initialize()
      assert kernel.run()
      assert ROOT.completed_events() == 3
      assert kernel.terminate()
    PYTHON
    system "bash", "-c", <<~SH
      unset DD4HEP_LIBRARY_PATH DYLD_LIBRARY_PATH LD_LIBRARY_PATH ROOT_INCLUDE_PATH
      source "#{formula_opt_bin("paulgessinger/hep/geant4")}/geant4.sh"
      source "#{bin}/thisdd4hep_only.sh"
      "#{formula_opt_bin("python@3.14")}/python3.14" "#{testpath}/test.py" || exit $?
      exec "#{formula_opt_bin("python@3.14")}/python3.14" "#{testpath}/simulation.py"
    SH
  end
end

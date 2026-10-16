class Geomodel < Formula
  desc "Detector geometry description toolkit for high energy physics"
  homepage "https://gitlab.cern.ch/GeoModelDev/GeoModel"
  url "https://gitlab.cern.ch/GeoModelDev/GeoModel/-/archive/6.32.0/GeoModel-6.32.0.tar.bz2"
  sha256 "05fcdd939d6f6200f5fd6565843f501395c44783c700c19a5f9a1ff023cb5b88"
  license "Apache-2.0"

  depends_on "cmake" => [:build, :test]
  depends_on "ninja" => :build
  depends_on "eigen"
  depends_on "nlohmann-json"
  depends_on "paulgessinger/hep/geant4"
  depends_on "sqlite"
  depends_on "xerces-c"
  depends_on "zlib"

  def install
    system "cmake", "-S", ".", "-B", "build", "-G", "Ninja",
                    "-DCMAKE_CXX_STANDARD=20",
                    "-DGEOMODEL_BUILD_TOOLS=ON",
                    "-DGEOMODEL_BUILD_VISUALIZATION=OFF",
                    "-DGEOMODEL_BUILD_GEOMODELG4=ON",
                    "-DGeant4_DIR=#{formula_opt_lib("paulgessinger/hep/geant4")}/cmake/Geant4",
                    "-DGEOMODEL_BUILD_FULLSIMLIGHT=OFF",
                    "-DGEOMODEL_BUILD_FSL=OFF",
                    "-DGEOMODEL_BUILD_EXAMPLES=OFF",
                    "-DGEOMODEL_BUILD_TESTING=OFF",
                    "-DBUILD_TESTING=OFF",
                    "-DGEOMODEL_USE_BUILTIN_EIGEN3=OFF",
                    "-DGEOMODEL_USE_BUILTIN_JSON=OFF",
                    "-DGEOMODEL_USE_BUILTIN_XERCESC=OFF",
                    "-DSQLite3_ROOT=#{formula_opt_prefix("sqlite")}",
                    "-DZLIB_ROOT=#{formula_opt_prefix("zlib")}",
                    *std_cmake_args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"
  end

  test do
    (testpath/"CMakeLists.txt").write <<~CMAKE
      cmake_minimum_required(VERSION 3.26)
      project(geomodel_test LANGUAGES CXX)
      find_package(GeoModelTools REQUIRED CONFIG)
      find_package(Geant4 REQUIRED)
      find_package(GeoModelG4 REQUIRED CONFIG)
      add_executable(geomodel_test test.cpp)
      target_compile_features(geomodel_test PRIVATE cxx_std_20)
      target_link_libraries(geomodel_test PRIVATE
        GeoModelIO::GeoModelWrite GeoModelIO::GeoModelRead GeoModelTools::GeoModelXml
        GeoModel2G4 GeoMaterial2G4)
    CMAKE

    # Round-trip a geometry through SQLite using the installed CMake exports.
    (testpath/"test.cpp").write <<~CPP
      #include <GeoModelKernel/GeoBox.h>
      #include <GeoModelKernel/GeoElement.h>
      #include <GeoModelKernel/GeoLogVol.h>
      #include <GeoModelKernel/GeoMaterial.h>
      #include <GeoModelKernel/GeoPhysVol.h>
      #include <GeoModelRead/ReadGeoModel.h>
      #include <GeoModelWrite/WriteGeoModel.h>
      #include <GeoModel2G4/VolumeBuilder.h>
      #include <G4Box.hh>
      #include <G4Material.hh>
      #include <cmath>
      #include <memory>

      int main() {
        auto* material = new GeoMaterial("Silicon", 2.33 * GeoMaterial::s_volDensity);
        material->add(new GeoElement("Silicon", "Si", 14,
                                     28.085 * GeoModelKernelUnits::gram / GeoModelKernelUnits::mole));
        material->lock();
        auto* world = new GeoPhysVol(new GeoLogVol("World", new GeoBox(1, 2, 3), material));
        world->ref();
        {
          GMDBManager db("geometry.db");
          if (!db.checkIsDBOpen()) return 1;
          GeoModelIO::WriteGeoModel writer(db);
          world->exec(&writer);
          writer.saveToDB();
        }
        world->unref();
        auto db = std::make_shared<GMDBManager>("geometry.db");
        GeoModelIO::ReadGeoModel reader(db);
        const auto restored = reader.buildGeoModel();
        const auto* logical = restored->getLogVol();
        if (logical->getName() != "World") return 2;
        if (logical->getMaterial()->getName() != "Silicon") return 3;
        if (std::abs(logical->getShape()->volume() - 48.0) > 1e-9) return 4;
        VolumeBuilder converter("HomebrewTest");
        const auto* converted = converter.Build(restored);
        if (converted->GetName() != "World") return 5;
        if (converted->GetMaterial()->GetName() != "Silicon") return 6;
        const auto* box = dynamic_cast<const G4Box*>(converted->GetSolid());
        if (!box || std::abs(box->GetZHalfLength() - 3.0) > 1e-9) return 7;
        return std::abs(converted->GetMaterial()->GetDensity() - logical->getMaterial()->getDensity()) < 1e-9 ? 0 : 8;
      }
    CPP

    system "cmake", "-S", ".", "-B", "build", "-DCMAKE_PREFIX_PATH=#{prefix}",
                    "-DGeant4_DIR=#{formula_opt_lib("paulgessinger/hep/geant4")}/cmake/Geant4",
                    *std_cmake_args
    system "cmake", "--build", "build"
    system testpath/"build/geomodel_test"
    assert_path_exists testpath/"geometry.db"
  end
end

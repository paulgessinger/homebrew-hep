class Geant4 < Formula
  desc "Toolkit for the simulation of the passage of particles through matter"
  homepage "https://geant4.web.cern.ch/"
  url "https://github.com/Geant4/geant4/archive/refs/tags/v11.4.3.tar.gz"
  sha256 "9744527a2eb2cbc37f15b554fd653379fea57294e15fffa2db83fd484366c89d"
  license :cannot_represent # Geant4 Software License, version 1.0
  revision 2

  depends_on "cmake" => [:build, :test]
  depends_on "ninja" => :build
  depends_on "expat"
  depends_on "xerces-c"
  depends_on "zlib"

  resource "G4NDL" do
    url "https://cern.ch/geant4-data/datasets/G4NDL.4.7.1.tar.gz"
    sha256 "d3acae48622118d2579de24a54d533fb2416bf0da9dd288f1724df1485a46c7c"
  end

  resource "G4EMLOW" do
    url "https://cern.ch/geant4-data/datasets/G4EMLOW.8.8.tar.gz"
    sha256 "b60cfd63176f5d16107e2a25b35b235155032d1735d749670ca50fede12624cf"
  end

  resource "PhotonEvaporation" do
    url "https://cern.ch/geant4-data/datasets/G4PhotonEvaporation.6.1.2.tar.gz"
    sha256 "02149c0ab91d88ee24e78532558777e39a068b9fcdd199136101ff58e635e742"
  end

  resource "RadioactiveDecay" do
    url "https://cern.ch/geant4-data/datasets/G4RadioactiveDecay.6.1.2.tar.gz"
    sha256 "a40d7e3ebc64d35555c4a49d0ff1e0945cd605d84354d053121293914caea13a"
  end

  resource "G4PARTICLEXS" do
    url "https://cern.ch/geant4-data/datasets/G4PARTICLEXS.4.2.tar.gz"
    sha256 "c52bbf86aaa589b78aba80b16ab0adf1041ea300de5395865b97fcee6eb55851"
  end

  resource "G4PII" do
    url "https://cern.ch/geant4-data/datasets/G4PII.1.3.tar.gz"
    sha256 "6225ad902675f4381c98c6ba25fc5a06ce87549aa979634d3d03491d6616e926"
  end

  resource "RealSurface" do
    url "https://cern.ch/geant4-data/datasets/G4RealSurface.2.2.tar.gz"
    sha256 "9954dee0012f5331267f783690e912e72db5bf52ea9babecd12ea22282176820"
  end

  resource "G4SAIDDATA" do
    url "https://cern.ch/geant4-data/datasets/G4SAIDDATA.2.0.tar.gz"
    sha256 "1d26a8e79baa71e44d5759b9f55a67e8b7ede31751316a9e9037d80090c72e91"
  end

  resource "G4ABLA" do
    url "https://cern.ch/geant4-data/datasets/G4ABLA.3.3.tar.gz"
    sha256 "1e041b3252ee9cef886d624f753e693303aa32d7e5ef3bba87b34f36d92ea2b1"
  end

  resource "G4INCL" do
    url "https://cern.ch/geant4-data/datasets/G4INCL.1.3.tar.gz"
    sha256 "e4b3dbe52acef53536454e22443091212843821bd23628eed846d299599f3bf9"
  end

  resource "G4ENSDFSTATE" do
    url "https://cern.ch/geant4-data/datasets/G4ENSDFSTATE.3.0.tar.gz"
    sha256 "4bdc3bd40b31d43485bf4f87f055705e540a6557d64ed85c689c59c9a4eba7d6"
  end

  resource "G4CHANNELING" do
    url "https://cern.ch/geant4-data/datasets/G4CHANNELING.2.0.tar.gz"
    sha256 "662159288644e07b79d7fe091efbebba52b59546b3dc6f5d285b976ad12f2d06"
  end

  def install
    # Stage checksummed datasets before configuring; CMake must not download data.
    resources.each do |r|
      (pkgshare/"data"/"#{r.name}#{r.version}").install r
    end

    system "cmake", "-S", ".", "-B", "build", "-G", "Ninja",
                    "-DCMAKE_CXX_STANDARD=20",
                    "-DGEANT4_BUILD_MULTITHREADED=ON",
                    "-DGEANT4_BUILD_TLS_MODEL=global-dynamic",
                    "-DGEANT4_USE_GDML=ON",
                    "-DGEANT4_USE_SYSTEM_EXPAT=ON",
                    "-DGEANT4_USE_SYSTEM_ZLIB=ON",
                    "-DGEANT4_USE_SYSTEM_CLHEP=OFF",
                    "-DEXPAT_ROOT=#{formula_opt_prefix("expat")}",
                    "-DZLIB_ROOT=#{formula_opt_prefix("zlib")}",
                    "-DGEANT4_INSTALL_PACKAGE_CACHE=ON",
                    "-DGEANT4_USE_QT=OFF",
                    "-DGEANT4_USE_OPENGL_X11=OFF",
                    "-DGEANT4_INSTALL_DATA=OFF",
                    "-DGEANT4_INSTALL_EXAMPLES=OFF",
                    *std_cmake_args,
                    "-DCMAKE_INSTALL_DATADIR=share/geant4",
                    "-DGEANT4_INSTALL_DATADIR=share/geant4/data"
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"
    pkgshare.install "LICENSE"
  end

  def caveats
    <<~EOS
      This build includes multithreading, GDML and the standard physics datasets.
      Qt and OpenGL visualization are not included.

      Set up Geant4 in bash or zsh:
        source #{opt_bin}/geant4.sh

      For CMake clients, pass -DGeant4_DIR=#{opt_lib}/cmake/Geant4.
    EOS
  end

  test do
    (testpath/"CMakeLists.txt").write <<~CMAKE
      cmake_minimum_required(VERSION 3.16)
      project(geant4_test LANGUAGES CXX)
      find_package(Geant4 REQUIRED gdml multithreaded)
      add_executable(geant4_test test.cpp)
      target_link_libraries(geant4_test PRIVATE ${Geant4_LIBRARIES})
    CMAKE

    (testpath/"test.cpp").write <<~CPP
      #include <FTFP_BERT.hh>
      #include <G4Box.hh>
      #include <G4GDMLParser.hh>
      #include <G4LogicalVolume.hh>
      #include <G4MTRunManager.hh>
      #include <G4NistManager.hh>
      #include <G4PVPlacement.hh>
      #include <G4ParticleGun.hh>
      #include <G4Gamma.hh>
      #include <G4Run.hh>
      #include <G4SystemOfUnits.hh>
      #include <G4VUserActionInitialization.hh>
      #include <G4VUserDetectorConstruction.hh>
      #include <G4VUserPrimaryGeneratorAction.hh>
      class Detector : public G4VUserDetectorConstruction {
        G4VPhysicalVolume* Construct() override {
          auto* material = G4NistManager::Instance()->FindOrBuildMaterial("G4_WATER");
          auto* solid = new G4Box("world", 10*cm, 10*cm, 10*cm);
          auto* logical = new G4LogicalVolume(solid, material, "world");
          auto* world = new G4PVPlacement(nullptr, {}, logical, "world", nullptr, false, 0);
          G4GDMLParser parser;
          parser.Write("world.gdml", world);
          return world;
        }
      };
      class Primary : public G4VUserPrimaryGeneratorAction {
        G4ParticleGun gun{1};
        void GeneratePrimaries(G4Event* event) override {
          gun.SetParticleDefinition(G4Gamma::GammaDefinition());
          gun.SetParticleEnergy(1*MeV);
          gun.SetParticleMomentumDirection({0, 0, 1});
          gun.GeneratePrimaryVertex(event);
        }
      };
      class Actions : public G4VUserActionInitialization {
        void Build() const override { SetUserAction(new Primary); }
      };
      int main() {
        G4MTRunManager manager;
        manager.SetNumberOfThreads(2);
        manager.SetUserInitialization(new Detector);
        manager.SetUserInitialization(new FTFP_BERT);
        manager.SetUserInitialization(new Actions);
        manager.Initialize();
        manager.BeamOn(5);
        return manager.GetCurrentRun()->GetNumberOfEvent() == 5 ? 0 : 1;
      }
    CPP

    system "cmake", "-S", ".", "-B", "build", "-DGeant4_DIR=#{lib}/cmake/Geant4", *std_cmake_args
    system "cmake", "--build", "build"
    system "bash", "-c", "source '#{bin}/geant4.sh' && exec '#{testpath}/build/geant4_test'"
    assert_path_exists testpath/"world.gdml"
    assert_match "G4_WATER", (testpath/"world.gdml").read
  end
end

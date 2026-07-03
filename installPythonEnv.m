% installPythonEnv - Install standalone Python 3.10 and VLA model dependencies.
%   Downloads a self-contained Python distribution (no system Python needed),
%   then installs packages required by the Octo and RT1-X model wrappers.
%
%   Supported architectures: glnxa64 (Linux), win64 (Windows).
%   macOS ARM64 (maca64) is not yet supported.

arch = computer('arch');
installLocation = fullfile(pwd,  arch);

pyVersion = "3.10.4";
switch arch
    case 'glnxa64'
        % Using install_only variant (no zstd dependency required for extraction)
        pySource = 'https://github.com/indygreg/python-build-standalone/releases/download/20220528/cpython-3.10.4+20220528-x86_64-unknown-linux-gnu-install_only.tar.gz';
    case 'win64'
        pySource = "https://github.com/indygreg/python-build-standalone/releases/download/20220528/cpython-3.10.4+20220528-x86_64-pc-windows-msvc-shared-install_only.tar.gz";
    case 'maca64'
        Error('Installation not supported');
end

tic
if ~exist(fullfile(installLocation, "python"), 'dir')
    mkdir(installLocation)
    disp("Downloading Python: " + pyVersion)
    pydlLoc = websave(fullfile(installLocation, "pydl"), pySource);
    tic
    disp("Extracting Python: " + pydlLoc)
    untar(pydlLoc, installLocation);
    delete(pydlLoc)
    toc
else
    disp("Python already installed at: " + installLocation + filesep + "python")
end

% Persist interpreter path in MATLAB settings for use by configurePyenv
if ispc
    pyInterpreter = fullfile(installLocation, "python", "python");
else
    pyInterpreter = fullfile(installLocation, "python", "bin", "python3.10");
end
s = settings;
if ~hasGroup(s, 'python')
    addGroup(s,'python');
end

if hasSetting(s.python,"Python")
    s.python.Python.PersonalValue = pyInterpreter;
else
    addSetting(s.python,"Python","PersonalValue", pyInterpreter);
end

% Quote pyInterpreter for system() - path may contain spaces (e.g., "00 Project - demo")
pyExe = '"' + pyInterpreter + '"';

disp("Upgrading pip and setuptools")
[status, cmdout] = system(pyExe + " -m pip install --upgrade pip wheel");
if status~=0
    error("pip upgrade failed (exit code %d):\n%s", status, cmdout)
end

disp("----------")
disp("Downloading and installing VLA Python dependencies")
[status, cmdout] = system(pyExe + " -m pip install -r vlapy/requirements.txt -c vlapy/constraints.txt", "-echo");
if status~=0
    error("pip install failed (exit code %d):\n%s", status, cmdout)
end

% Octo installed from pinned commit with --no-deps to avoid conflicting transitive deps
disp("----------")
disp("Installing Octo")
[status, cmdout] = system(pyExe + " -m pip install git+https://github.com/octo-models/octo.git@241fb3514b7c40957a86d869fecb7c7fc353f540 --no-deps", "-echo");
if status~=0
    error("pip install failed (exit code %d):\n%s", status, cmdout)
end
toc

% Download Octo model weights from MathWorks support files
% (avoids Windows symlink permission errors with huggingface_hub)
disp("----------")
disp("Downloading Octo model weights")
modelsDir = fullfile(fileparts(mfilename('fullpath')), "vlapy", "octo-base");
if ~exist(modelsDir, 'dir')
    filename = matlab.internal.examples.downloadSupportFile("robotics/data", "octoBaseModel.zip");
    disp("Extracting: " + filename)
    unzip(filename, fullfile(fileparts(mfilename('fullpath')), "vlapy"));
else
    disp("Octo model already downloaded at: " + modelsDir)
end
toc

% Setup the python interpreter
terminate(pyenv);
pyenv(Version=pyInterpreter, ExecutionMode="OutOfProcess");

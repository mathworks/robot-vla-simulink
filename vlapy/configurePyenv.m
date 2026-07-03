function penv = configurePyenv
% configurePyenv Configure Python environment for VLA project
%   penv = configurePyenv() sets up the Python environment with the
%   appropriate interpreter based on the system architecture and adds
%   the VLA module path to the Python system path.
%
%   Output:
%       penv - Configured Python environment object
%
%   The function automatically detects the system architecture and
%   configures the Python interpreter path accordingly. It also ensures
%   the VLA module path is added to Python's sys.path for module imports.

arch = computer('arch');
rootDir = fullfile(fileparts(mfilename("fullpath")), '..');
installLocation = fullfile(rootDir, arch);
if ispc
    pyInterpreter = fullfile(installLocation, "python", "python");
else
    pyInterpreter = fullfile(installLocation, "python", "bin", "python3.10");
end

if ~isfile(pyInterpreter+'.exe')
    error("Python interpreter not found at: %s. Please run installPythonEnv", pyInterpreter);
end

% Restart Python to ensure clean state with the project-local interpreter
terminate(pyenv);
penv = pyenv(Version=pyInterpreter, ExecutionMode="OutOfProcess");

% vlapy must be on sys.path so Python can import model modules (rt1xModel, octoModel)
modulePath = fullfile(rootDir, "vlapy");
if count(py.sys.path, modulePath) == 0    
    insert(py.sys.path, int64(0), modulePath);
end
classdef (StrictDefaults) robotpolicy < matlab.System
    % robotPolicy Wrapper to robotic vision-language-action models. 
    %    This class provides access to pre-trained robotic
    %    models including RT1-X and Octo models for robot control based on
    %    visual inputs and task descriptions.
    %
    % Properties:
    %   ModelName - Name of the model to use ("RT1-X" or "Octo")
    %
    % Example:
    %   policy = robotPolicy('ModelName', 'Octo');
    %   action = policy(image);

    % Copyright 2026 The MathWorks, Inc.

    properties(Nontunable)
        ModelName {mustBeMember(ModelName,["RT1X","Octo"])} = "Octo"
    end    

    properties (Access = private)
       Model
       IsModelDirty (1,1) logical = true
       TaskDescription (1,:) string = ""
    end

    methods
        function obj = robotpolicy(varargin)
            setProperties(obj,nargin,varargin{:}, 'ModelName');            
            configurePyenv;
        end
    end

    methods (Access = protected)
        function setupImpl(obj, ~, task)
            % Import and initialize the selected VLA model via Python interop.
            % Called once at first step or when ModelName changes.

            if isempty(task) && obj.TaskDescription ~= task
                obj.TaskDescription = task;
            end

            if obj.IsModelDirty
                sprintf("Loading %s model..\n", obj.ModelName);
                if obj.ModelName == "RT1X"          
                    py.importlib.import_module("rt1xModel");       
                    obj.Model = py.rt1xModel.RT1Inference(...
                            saved_model_path=obj.getRt1xModelPath(),...
                            image_width=int32(320),...
                            image_height=int32(256),...
                            policy_setup="widowx_bridge");
                elseif obj.ModelName == "Octo"                  
                    py.importlib.import_module("octoModel");              
                    obj.Model = py.octoModel.OctoInference();
                end
                sprintf("Loaded %s model.\n", obj.ModelName);
            end
        end

        function action = stepImpl(obj, image, task)
            % step - Execute one step of the robot policy
            %   Converts current camera images and task description to
            %   generate robot action commands for end-effector control
            %   including position, orientation, and gripper state.
            %
            % Inputs:
            %   task - String describing the task to perform
            %   image - RGB image as uint8 array of size (:,:,3)
            %
            % Outputs:
            %   action - 7x1 vector containing:
            %     [x, y, z, yaw, pitch, roll, gripper_state]
            arguments
                obj                
                image (:,:,3) uint8
                task (1,:) string
            end
            
            image = py.numpy.array(image);
            action = obj.Model.step(image, task);
                        
            xyz = double(action{2}{'world_vector'});
            rotRPY = double(action{2}{'rot_axangle'});
            rotYPR = rotRPY([3,2,1]); % Reorder from RPY to YPR for end-effector convention
            gripper = double(action{2}{'gripper'});
            action = [xyz, rotYPR, gripper];
            action = action(:);
        end

        function resetImpl(obj)            
            obj.Model.reset(obj.TaskDescription)
        end

        function s = saveObjectImpl(obj)
            s = saveObjectImpl@matlab.System(obj);
        end

        function loadObjectImpl(obj,s,wasLocked)
            loadObjectImpl@matlab.System(obj,s,wasLocked);
        end
       
        function ds = getDiscreteStateImpl(~)
            ds = struct([]);
        end

        function num = getNumInputsImpl(~)
            num = 2;
        end

        function num = getNumOutputsImpl(~)
            num = 1;
        end

        function out = getOutputSizeImpl(~)
            out = 7;
        end

        function out = getOutputDataTypeImpl(~)
            out = "double";
        end

        function out = isOutputComplexImpl(~)
            out = false;
        end

        function out = isOutputFixedSizeImpl(~)
            out = true;
        end

        function sts = getSampleTimeImpl(obj)
            sts = obj.createSampleTime("Type", "Discrete", "SampleTime", 1);
        end

        function icon = getIconImpl(~)
            filepath = mfilename('fullpath');
            [filedir, ~, ~] = fileparts(filepath);
            imagePath = fullfile(filedir, "images", "robotpolicy.png");            
            icon = matlab.system.display.Icon(imagePath);
        end

        function name = getInputNamesImpl(~)
            name = ["image", "task"];
        end

        function name = getOutputNamesImpl(~)
            name = "action";
        end        
    end

    methods
        function set.ModelName(obj, name)
            obj.ModelName = name;
            obj.setModelDirty();
        end
    end

    methods(Access=private)
        function setModelDirty(obj)
            obj.IsModelDirty = true;
        end
    end
    
    methods (Static, Access = protected)        
        function header = getHeaderImpl
            header = matlab.system.display.Header(mfilename("class"));
        end

        function simMode = getSimulateUsingImpl
            % Python interop requires interpreted execution (no code generation)
            simMode = "Interpreted execution";
        end

        function flag = showSimulateUsingImpl
            % Hide simulation mode selector since only interpreted mode is supported
            flag = false;
        end
    end

    methods(Static, Access=private)
        function rt1xCkpt = getRt1xModelPath

            vlaPath  = fullfile(fileparts(mfilename("fullpath")), "vlapy");
            rt1xZip  = fullfile(vlaPath, "rt1xModel.zip"); 
            rt1xCkpt = fullfile(vlaPath, "rt_1_x_tf_trained_for_002272480_step");

            % Lazy download: fetch RT1-X checkpoint from MathWorks server on first use
            if ~exist(rt1xZip, "file")
                disp("Model not found locally. Downloading from remote server...")
                datasetURL = "https://ssd.mathworks.com/supportfiles/robotics/data/rt1xModel.zip";
                websave(rt1xZip, datasetURL); 
                disp("Download complete. Extracting files...")
                unzip(rt1xZip, vlaPath)
            end        
        end    
    end
end
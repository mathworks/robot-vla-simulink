classdef grippercontrol < matlab.System
% GRIPPERCONTROL PD position controller for two-finger parallel jaw grippers.
%
% Runs a PD position controller over multiple sim steps per control step,
% approximating the SAPIEN/PhysX articulation drive with semi-implicit Euler.
% Mass is treated as unity (PD output = acceleration); steady-state positions
% match PhysX, but transient dynamics differ.
%
% Supports WidowX (BridgeData) and GoogleRobot via tunable properties.
% Defaults are WidowX.
%
% Inputs:
%   command - Normalized gripper command in [-1,+1] (from gripperCommand)
%
% Outputs:
%   fingerPositionLeft  - Left finger position after PD sim [m or rad]
%   fingerPositionRight - Right finger position after PD sim [m or rad]
%
% Usage (WidowX):
%   ctrl = gripperControl;
%   cmd = gripperCommand(octoAction, true);
%   [posLeft, posRight] = ctrl(cmd);
%
%
% Maintains finger position and velocity state between calls.
% Call reset(ctrl) to reinitialize to the open configuration.


    % Joint limits from URDF; clearance extends the target range so the PD
    % controller drives into the limit clamp, producing sustained holding force.
    properties
        FingerPositionMin (1,1) double  = 0.015   % Joint lower limit [m or rad]
        FingerPositionMax (1,1) double  = 0.037   % Joint upper limit [m or rad]
        Clearance         (1,1) double  = 0.001   % Target overshoot beyond limits [m or rad]
    end

    properties
        StiffnessKp        (1,1) double = 1000   % PD proportional gain [N/m or N*m/rad]
        DampingKd          (1,1) double = 200    % PD derivative gain [N*s/m or N*m*s/rad]
        EffortLimit        (1,1) double = 60     % Force/torque clamp [N or N*m]
        SimFrequency       (1,1) double = 500    % Physics simulation frequency [Hz]
        ControlFrequency   (1,1) double = 5      % Policy control frequency [Hz]
    end

    properties (Access = private)
        FingerPositionLeft  (1,1) double
        FingerPositionRight (1,1) double
        FingerVelocityLeft  (1,1) double
        FingerVelocityRight (1,1) double
    end

    methods (Access = private)

        function initializeState(obj)
            % Start fully open (position at upper limit, zero velocity)
            obj.FingerPositionLeft  = obj.FingerPositionMax;
            obj.FingerPositionRight = obj.FingerPositionMax;
            obj.FingerVelocityLeft  = 0;
            obj.FingerVelocityRight = 0;
        end
    end

    methods (Access = protected)

        function setupImpl(obj)
            initializeState(obj);
        end

        function resetImpl(obj)
            initializeState(obj);
        end

        function [fingerPositionLeft, fingerPositionRight] = stepImpl(obj, command)

            % Target extends beyond joint limits by Clearance so the position
            % clamp produces a residual error = Clearance, giving sustained
            % holding force = Kp * Clearance (e.g. 1000 * 0.001 = 1 N).
            scaleLow  = obj.FingerPositionMin - obj.Clearance;
            scaleHigh = obj.FingerPositionMax + obj.Clearance;
            jointTarget = 0.5 * (scaleHigh + scaleLow) ...
                        + 0.5 * (scaleHigh - scaleLow) * command;

            % Mimic controller: both fingers track the same target
            numSimSteps = obj.SimFrequency / obj.ControlFrequency;
            timeStep = 1 / obj.SimFrequency;

            posLeft   = obj.FingerPositionLeft;
            posRight  = obj.FingerPositionRight;
            velLeft   = obj.FingerVelocityLeft;
            velRight  = obj.FingerVelocityRight;

            % PhysX PD drive: force = Kp*(target - q) - Kd*qdot, clamped.
            % Semi-implicit Euler: update velocity first, then position.
            for simStep = 1:numSimSteps % fixed iteration count
                forceLeft  = obj.StiffnessKp * (jointTarget - posLeft) ...
                             - obj.DampingKd * velLeft;
                forceRight = obj.StiffnessKp * (jointTarget - posRight) ...
                             - obj.DampingKd * velRight;

                forceLeft  = clamp(forceLeft,  -obj.EffortLimit, obj.EffortLimit);
                forceRight = clamp(forceRight, -obj.EffortLimit, obj.EffortLimit);

                velLeft  = velLeft  + forceLeft  * timeStep;
                velRight = velRight + forceRight * timeStep;
                posLeft  = posLeft  + velLeft  * timeStep;
                posRight = posRight + velRight * timeStep;

                posLeft  = clamp(posLeft,  obj.FingerPositionMin, obj.FingerPositionMax);
                posRight = clamp(posRight, obj.FingerPositionMin, obj.FingerPositionMax);
            end

            obj.FingerPositionLeft  = posLeft;
            obj.FingerPositionRight = posRight;
            obj.FingerVelocityLeft  = velLeft;
            obj.FingerVelocityRight = velRight;

            fingerPositionLeft  = posLeft;
            fingerPositionRight = posRight;
        end

        function numIn = getNumInputsImpl(~)
            numIn = 1;
        end

        function numOut = getNumOutputsImpl(~)
            numOut = 2;
        end
    end
end

function clamped = clamp(value, lowerBound, upperBound)
    clamped = min(max(value, lowerBound), upperBound);
end
% OVERVIEW
% augmentFilter.m augments the output matrices in order to 
%                 accomodate additional states for anticipated shocks: 
% 
% The state transition equation is: S_t = TTT*S_t-1+RRR*eps_t
% The measurement equation is: Y_t = ZZ*S_t+DD
%
% INPUTS
% r_tl1: 
% r_tlx: 
% nant: number of anticipated shocks
% antlags: number of past periods in which the zerobound was in effect
% ind_r: variable indexing the FFR among all observable variables 
% zend: end-of-sample smoothed state from the model without anticipated
%       shocks
% pend: end-of-sample smoothed states covariance matrix from 
%       the model without anticipated shocks
% YY: matrix of observable data
%
% OUTPUTS
% zprev: vector of filtered states
% pprev: matrix of filtered state covariances 
% MM_ant
% EE_ant: variance of expectational error
% ZZ_e: nant period ahead measurement equation matrix (maps
%       states into observables. 
% DD_e: nant period ahead steady state vector.
% YY_ant: data matrix that includes nant periods of zerobound
%         (0.25) FFR
% 

function [zprev,pprev,MM_ant,EE_ant,ZZ_e,DD_e,YY_ant] = augmentFilter(r_tl1,r_tlx,nant,antlags,ind_r,zend,pend,MM,EE,ZZ,DD,YY,TTT,ExpFFR)

% We have added states so the results from filtering using
% the old model now have the wrong dimension, so create new
% predicted states (zprev) and state covariance matrices (pprev)
% that have zeros in the rows and columns corresponding to
% the new anticipated shock states.

zprev = zeros(size(TTT,1),1);
zprev(1:r_tlx-2) = zend(1:r_tlx-2,end);
zprev(r_tl1+nant:end) = zend(r_tlx-1:end,end);

pprev = zeros(size(TTT));
pprev(1:r_tlx-2,1:r_tlx-2) = pend(1:r_tlx-2,1:r_tlx-2,end);
pprev(r_tl1+nant:end,1:r_tlx-2) = pend(r_tlx-1:end,1:r_tlx-2,end);
pprev(1:r_tlx-2,r_tl1+nant:end) = pend(1:r_tlx-2,r_tlx-1:end,end);
pprev(r_tl1+nant:end,r_tl1+nant:end) = pend(r_tlx-1:end,r_tlx-1:end,end);

MM_ant = zeros(size(MM,1)+nant,size(MM,2));
EE_ant = zeros(size(EE,1)+nant,size(EE,2)+nant);

% Now create the augmented measurement equation. We need to create
% a transformation to go from model states to our new "observable"
% of the expected interest rate i periods ahead, where i ranges
% from 1 to nant, the number of periods we are fixing.

% To find the expected interest rate i periods ahead given the
% model states, note that the expected states in i periods is just
% the current states vector with the TTT matrix applied i times).
% So to get the expected interest rate we just apply the "interest
% rate" row of the current ZZ matrix to the expected states vector,
% or equivalently to TTT^i applied to the current states vector.

ZZ_e = zeros(size(ZZ,1) + nant,size(ZZ,2));
ZZ_e(1:size(ZZ,1),:) = ZZ;

for i = 1:nant
ZZ_e(size(ZZ,1) + i,:) = ZZ(ind_r,:)*(TTT^i);
end

DD_e = [DD;repmat(DD(ind_r),nant,1)];

% Augmenting the data, assuming a path fixed at 0.25.
% Change to change the path to which interest rate
% expectations are fixed.

% Add a catch so we can forecast 
%   It might be that ExpFFR is "too big" relative to antlags for a
%   particular model.
%       
%   This could be because the ExpFFR_OIS.m file has been updated with a new
%   quarter of data, but the rest of the quarterly data (GDP, PCE, etc.)
%   has not. In this case, we'd want to chop off the bottom of the ExpFFR
%   matrix.
%
%   Or, it could be the case that we shorten antlags so that the ZB period
%   starts one or more quarters later. In this case, we'd want to chop off
%   the top of the ExpFFR matrix. 
%
%   Since chopping off the top or bottom of ExpFFR cannot be determined
%   solely from antlags (or the discrepancy between the size of ExpFFR and
%   the subset of YY we take based on antlags, we need to be more explicit
%   about what we want to do.
%
%   For that reason, we have "delay," which is the number of quarters AFTER
%   2008Q4 (the usual ZB start) in which we should start the ZB period. We NaN
%   out the other periods before delay. You should also decrement antlags by 1.
%   
%   MDC 7/21/2014

% How many quarters to delay the ZB period; use this in concjunction with changing antlags
delay = 0;

try 
    % YY_ant = [YY(end-antlags:end,:),repmat(0.25,antlags+1,nant)];
    YY_ant = [YY(end-antlags:end,:),[nan(delay,size(ExpFFR,2)); ExpFFR(1+delay:end,:)] ]; 
catch
    YY_ant = [YY(end-antlags:end,:),[nan(delay,size(ExpFFR,2)); ExpFFR(1+delay:antlags+1,:)] ]; 
end



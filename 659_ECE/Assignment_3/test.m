clc;
clear;
n = 512;
k = 128;
p = randperm(n);
X_0 = zeros(512,1);
X_0(p(1:k)) = sign(randn(k, 1));

% Part A Plot of Original Signal  
subplot(3,1,1);
plot(1:n, X_0);
axis([0 512 -1.5 1.5]);
title('Original Signal');



% Part B Compression of the Original Data 
m = 128;
A = randn(k, n);
% A = Gaussian(m,n,2);
b = A * X_0 + 0.005 * randn(m,1);
subplot(3,1,2);
plot(1:m, b, 'g');
title('Compressed Signal');

% Part C Recovery of the Original data
pdtol = 0.001;
pdmaxiter = 50;
cgtol = 0.00000001;
cgmaxiter = 200;
x_test = A.'*b
original_data = l1eq_pd(X_0, A,[], b); %, pdtol, pdmaxiter, cgtol, cgmaxiter);
% Part A Plot of Original Signal  
subplot(3,1,3);
plot(1:n, original_data, 'r');
axis([0 512 -1.5 1.5]);
title('Recovered Signal');


function xp = l1eq_pd(x0, A, At, b, pdtol, pdmaxiter, cgtol, cgmaxiter)

largescale = isa(A,'function_handle');

if (nargin < 5), pdtol = 1e-3;  end
if (nargin < 6), pdmaxiter = 50;  end
if (nargin < 7), cgtol = 1e-8;  end
if (nargin < 8), cgmaxiter = 200;  end

N = length(x0);

alpha = 0.01;
beta = 0.5;
mu = 10;

gradf0 = [zeros(N,1); ones(N,1)];

% starting point --- make sure that it is feasible
if (largescale)
  if (norm(A(x0)-b)/norm(b) > cgtol)
    disp('Starting point infeasible; using x0 = At*inv(AAt)*y.');
    AAt = @(z) A(At(z));
    [w, cgres, cgiter] = cgsolve(AAt, b, cgtol, cgmaxiter, 0);
    if (cgres > 1/2)
      disp('A*At is ill-conditioned: cannot find starting point');
      xp = x0;
      return;
    end
    x0 = At(w);
  end
else
  if (norm(A*x0-b)/norm(b) > cgtol)
    disp('Starting point infeasible; using x0 = At*inv(AAt)*y.');
    opts.POSDEF = true; opts.SYM = true;
    [w, hcond] = linsolve(A*A', b, opts);
    if (hcond < 1e-14)
      disp('A*At is ill-conditioned: cannot find starting point');
      xp = x0;
      return;
    end
    x0 = A'*w;
  end  
end
x = x0;
u = (0.95)*abs(x0) + (0.10)*max(abs(x0));

% set up for the first iteration
fu1 = x - u;
fu2 = -x - u;
lamu1 = -1./fu1;
lamu2 = -1./fu2;
if (largescale)
  v = -A(lamu1-lamu2);
  Atv = At(v);
  rpri = A(x) - b;
else
  v = -A*(lamu1-lamu2);
  Atv = A'*v;
  rpri = A*x - b;
end

sdg = -(fu1'*lamu1 + fu2'*lamu2);
tau = mu*2*N/sdg;

rcent = [-lamu1.*fu1; -lamu2.*fu2] - (1/tau);
rdual = gradf0 + [lamu1-lamu2; -lamu1-lamu2] + [Atv; zeros(N,1)];
resnorm = norm([rdual; rcent; rpri]);

pditer = 0;
done = (sdg < pdtol) | (pditer >= pdmaxiter);
while (~done)
  
  pditer = pditer + 1;
  
  w1 = -1/tau*(-1./fu1 + 1./fu2) - Atv;
  w2 = -1 - 1/tau*(1./fu1 + 1./fu2);
  w3 = -rpri;
  
  sig1 = -lamu1./fu1 - lamu2./fu2;
  sig2 = lamu1./fu1 - lamu2./fu2;
  sigx = sig1 - sig2.^2./sig1;
  
  if (largescale)
    w1p = w3 - A(w1./sigx - w2.*sig2./(sigx.*sig1));
    h11pfun = @(z) -A(1./sigx.*At(z));
    [dv, cgres, cgiter] = cgsolve(h11pfun, w1p, cgtol, cgmaxiter, 0);
    if (cgres > 1/2)
      disp('Cannot solve system.  Returning previous iterate.  (See Section 4 of notes for more information.)');
      xp = x;
      return
    end
    dx = (w1 - w2.*sig2./sig1 - At(dv))./sigx;
    Adx = A(dx);
    Atdv = At(dv);
  else
    w1p = -(w3 - A*(w1./sigx - w2.*sig2./(sigx.*sig1)));
    H11p = A*(sparse(diag(1./sigx))*A');
    % opts.POSDEF = true; opts.SYM = true; % by Quan Wang
    % [dv,hcond] = linsolve(H11p, w1p, opts); % by Quan Wang
    [dv,hcond] = linsolve(H11p, w1p); % by Quan Wang
    if (hcond < 1e-14)
      disp('Matrix ill-conditioned.  Returning previous iterate.  (See Section 4 of notes for more information.)');
      xp = x;
      return
    end
    dx = (w1 - w2.*sig2./sig1 - A'*dv)./sigx;
    Adx = A*dx;
    Atdv = A'*dv;
  end
  
  du = (w2 - sig2.*dx)./sig1;
  
  dlamu1 = (lamu1./fu1).*(-dx+du) - lamu1 - (1/tau)*1./fu1;
  dlamu2 = (lamu2./fu2).*(dx+du) - lamu2 - 1/tau*1./fu2;
  
  % make sure that the step is feasible: keeps lamu1,lamu2 > 0, fu1,fu2 < 0
  indp = find(dlamu1 < 0);  indn = find(dlamu2 < 0);
  s = min([1; -lamu1(indp)./dlamu1(indp); -lamu2(indn)./dlamu2(indn)]);
  indp = find((dx-du) > 0);  indn = find((-dx-du) > 0);
  s = (0.99)*min([s; -fu1(indp)./(dx(indp)-du(indp)); -fu2(indn)./(-dx(indn)-du(indn))]);
  
  % backtracking line search
  suffdec = 0;
  backiter = 0;
  while (~suffdec)
    xp = x + s*dx;  up = u + s*du; 
    vp = v + s*dv;  Atvp = Atv + s*Atdv; 
    lamu1p = lamu1 + s*dlamu1;  lamu2p = lamu2 + s*dlamu2;
    fu1p = xp - up;  fu2p = -xp - up;  
    rdp = gradf0 + [lamu1p-lamu2p; -lamu1p-lamu2p] + [Atvp; zeros(N,1)];
    rcp = [-lamu1p.*fu1p; -lamu2p.*fu2p] - (1/tau);
    rpp = rpri + s*Adx;
    suffdec = (norm([rdp; rcp; rpp]) <= (1-alpha*s)*resnorm);
    s = beta*s;
    backiter = backiter + 1;
    if (backiter > 32)
      disp('Stuck backtracking, returning last iterate.  (See Section 4 of notes for more information.)')
      xp = x;
      return
    end
  end
  
  
  % next iteration
  x = xp;  u = up;
  v = vp;  Atv = Atvp; 
  lamu1 = lamu1p;  lamu2 = lamu2p;
  fu1 = fu1p;  fu2 = fu2p;
  
  % surrogate duality gap
  sdg = -(fu1'*lamu1 + fu2'*lamu2);
  tau = mu*2*N/sdg;
  rpri = rpp;
  rcent = [-lamu1.*fu1; -lamu2.*fu2] - (1/tau);
  rdual = gradf0 + [lamu1-lamu2; -lamu1-lamu2] + [Atv; zeros(N,1)];
  resnorm = norm([rdual; rcent; rpri]);
  
  done = (sdg < pdtol) | (pditer >= pdmaxiter);
  
  disp(sprintf('Iteration = %d, tau = %8.3e, Primal = %8.3e, PDGap = %8.3e, Dual res = %8.3e, Primal res = %8.3e',...
    pditer, tau, sum(u), sdg, norm(rdual), norm(rpri)));
  if (largescale)
    disp(sprintf('                  CG Res = %8.3e, CG Iter = %d', cgres, cgiter));
  else
    disp(sprintf('                  H11p condition number = %8.3e', hcond));
  end
  
end

end 



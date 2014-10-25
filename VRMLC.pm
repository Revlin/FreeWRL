# Copyright (C) 1998 Tuomas J. Lukka
# DISTRIBUTED WITH NO WARRANTY, EXPRESS OR IMPLIED.
# See the GNU General Public License (file COPYING in the distribution)
# for conditions of use and redistribution.

# The C routines to render various nodes quickly
#
# Field values by subs so that generalization possible..
#
# getf(Node,"fieldname",[index,...]) returns c string to get field name.
# getaf(Node,"fieldname",n) returns comma-separated list of all the field values.
# getfn(Node,"fieldname"
#
# Of these, VP is taken into account by Transform
#
# Why so elaborate code generation?
#  - makes it easy to change structs later
#  - makes it very easy to add fast implementations for new proto'ed 
#    node types
#
#
# TODO:
#  Test indexedlineset
#  do normals for indexedfaceset

# To allow faster internal representations of nodes to be calculated,
# there is the field '_change' which can be compared between the node
# and the internal rep - if different, needs to be regenerated.
#
# the rep needs to be allocated if _intern == 0.
# XXX Freeing?!!?

require 'VRMLFields.pm';
require 'VRMLNodes.pm';
require 'VRMLRend.pm';

#######################################################################
#######################################################################
#######################################################################
#
# RendRay --
#  code for checking whether a ray (defined by mouse pointer)
#  intersects with the geometry of the primitive.
#
#

%RendRayC = (
Box => '
	float x = $f(size,0)/2;
	float y = $f(size,1)/2;
	float z = $f(size,2)/2;
	/* 1. x=const-plane faces? */
	if(!XEQ) {
		float xrat0 = XRAT(x);
		float xrat1 = XRAT(-x);
		if(verbose) printf("!XEQ: %f %f\n",xrat0,xrat1);
		if(TRAT(xrat0)) {
			float cy = MRATY(xrat0);
			if(verbose) printf("TRok: %f\n",cy);
			if(cy >= -y && cy < y) {
				float cz = MRATZ(xrat0);
				if(verbose) printf("cyok: %f\n",cz);
				if(cz >= -z && cz < z) {
					if(verbose) printf("czok:\n");
					HIT(xrat0, x,cy,cz, 1,0,0, -1,-1, "cube x0");
				}
			}
		}
		if(TRAT(xrat1)) {
			float cy = MRATY(xrat1);
			if(cy >= -y && cy < y) {
				float cz = MRATZ(xrat1);
				if(cz >= -z && cz < z) {
					HIT(xrat1, -x,cy,cz, -1,0,0, -1,-1, "cube x1");
				}
			}
		}
	}
	if(!YEQ) {
		float yrat0 = YRAT(y);
		float yrat1 = YRAT(-y);
		if(TRAT(yrat0)) {
			float cx = MRATX(yrat0);
			if(cx >= -x && cx < x) {
				float cz = MRATZ(yrat0);
				if(cz >= -z && cz < z) {
					HIT(yrat0, cx,y,cz, 0,1,0, -1,-1, "cube y0");
				}
			}
		}
		if(TRAT(yrat1)) {
			float cx = MRATX(yrat1);
			if(cx >= -x && cx < x) {
				float cz = MRATZ(yrat1);
				if(cz >= -z && cz < z) {
					HIT(yrat1, cx,-y,cz, 0,-1,0, -1,-1, "cube y1");
				}
			}
		}
	}
	if(!ZEQ) {
		float zrat0 = ZRAT(z);
		float zrat1 = ZRAT(-z);
		if(TRAT(zrat0)) {
			float cx = MRATX(zrat0);
			if(cx >= -x && cx < x) {
				float cy = MRATY(zrat0);
				if(cy >= -y && cy < y) {
					HIT(zrat0, cx,cy,z, 0,0,1, -1,-1,"cube z0");
				}
			}
		}
		if(TRAT(zrat1)) {
			float cx = MRATX(zrat1);
			if(cx >= -x && cx < x) {
				float cy = MRATY(zrat1);
				if(cy >= -y && cy < y) {
					HIT(zrat1, cx,cy,-z, 0,0,-1,  -1,-1,"cube z1");
				}
			}
		}
	}
',

# Distance to zero as function of ratio is
# sqrt(
#	((1-r)t_r1.x + r t_r2.x)**2 +
#	((1-r)t_r1.y + r t_r2.y)**2 +
#	((1-r)t_r1.z + r t_r2.z)**2
# ) == radius
# Therefore,
# radius ** 2 == ... ** 2 
# and 
# radius ** 2 = 
# 	(1-r)**2 * (t_r1.x**2 + t_r1.y**2 + t_r1.z**2) +
#       2*(r*(1-r)) * (t_r1.x*t_r2.x + t_r1.y*t_r2.y + t_r1.z*t_r2.z) +
#       r**2 (t_r2.x**2 ...)
# Let's name tr1sq, tr2sq, tr1tr2 and then we have
# radius ** 2 =  (1-r)**2 * tr1sq + 2 * r * (1-r) tr1tr2 + r**2 tr2sq
# = (tr1sq - 2*tr1tr2 + tr2sq) r**2 + 2 * r * (tr1tr2 - tr1sq) + tr1sq
# 
# I.e.
# 
# (tr1sq - 2*tr1tr2 + tr2sq) r**2 + 2 * r * (tr1tr2 - tr1sq) + 
#	(tr1sq - radius**2) == 0
#
# I.e. second degree eq. a r**2 + b r + c == 0 where
#  a = tr1sq - 2*tr1tr2 + tr2sq
#  b = 2*(tr1tr2 - tr1sq)
#  c = (tr1sq-radius**2)
# 
# 
Sphere => '
	float r = $f(radius);
	/* Center is at zero. t_r1 to t_r2 and t_r1 to zero are the vecs */
	float tr1sq = VECSQ(t_r1);
	float tr2sq = VECSQ(t_r2);
	float tr1tr2 = VECPT(t_r1,t_r2);
	struct pt dr2r1;
	float dlen;
	float a,b,c,disc;

	VECDIFF(t_r2,t_r1,dr2r1);
	dlen = VECSQ(dr2r1);

	a = dlen; /* tr1sq - 2*tr1tr2 + tr2sq; */
	b = 2*(VECPT(dr2r1, t_r1));
	c = tr1sq - r*r;

	disc = b*b - 4*a*c; /* The discriminant */
	
	if(disc > 0) { /* HITS */
		float q ;
		float sol1 ;
		float sol2 ;
		float cx,cy,cz;
		q = sqrt(disc);
		/* q = (-b+(b>0)?q:-q)/2; */
		sol1 = (-b+q)/(2*a);
		sol2 = (-b-q)/(2*a);
		/*
		printf("SPHSOL0: (%f %f %f) (%f %f %f)\n",
			t_r1.x, t_r1.y, t_r1.z, t_r2.x, t_r2.y, t_r2.z);
		printf("SPHSOL: (%f %f %f) (%f) (%f %f) (%f) (%f %f)\n",
			tr1sq, tr2sq, tr1tr2, a, b, c, und, sol1, sol2);
		*/
		cx = MRATX(sol1);
		cy = MRATY(sol1);
		cz = MRATZ(sol1);
		HIT(sol1, cx,cy,cz, cx/r,cy/r,cz/r, -1,-1, "sphere 0");
		cx = MRATX(sol2);
		cy = MRATY(sol2);
		cz = MRATZ(sol2);
		HIT(sol2, cx,cy,cz, cx/r,cy/r,cz/r, -1,-1, "sphere 1");
	}
',

# Cylinder: first test the caps, then against infinite cylinder.
Cylinder => '
	float h = $f(height)/2; /* pos and neg dir. */
	float r = $f(radius);
	float y = h;
	/* Caps */
	if(!YEQ) {
		float yrat0 = YRAT(y);
		float yrat1 = YRAT(-y);
		if(TRAT(yrat0)) {
			float cx = MRATX(yrat0);
			float cz = MRATZ(yrat0);
			if(r*r > cx*cx+cz*cz) {
				HIT(yrat0, cx,y,cz, 0,1,0, -1,-1, "cylcap 0");
			}
		}
		if(TRAT(yrat1)) {
			float cx = MRATX(yrat1);
			float cz = MRATZ(yrat1);
			if(r*r > cx*cx+cz*cz) {
				HIT(yrat1, cx,-y,cz, 0,-1,0, -1,-1, "cylcap 1");
			}
		}
	}
	/* Body -- do same as for sphere, except no y axis in distance */
	if((!XEQ) && (!ZEQ)) {
		float dx = t_r2.x-t_r1.x; float dz = t_r2.z-t_r1.z;
		float a = dx*dx + dz*dz;
		float b = 2*(dx * t_r1.x + dz * t_r1.z);
		float c = t_r1.x * t_r1.x + t_r1.z * t_r1.z - r*r;
		float und;
		b /= a; c /= a;
		und = b*b - 4*c;
		if(und > 0) { /* HITS the infinite cylinder */
			float sol1 = (-b+sqrt(und))/2;
			float sol2 = (-b-sqrt(und))/2;
			float cy,cx,cz;
			cy = MRATY(sol1);
			if(cy > -h && cy < h) {
				cx = MRATX(sol1);
				cz = MRATZ(sol1);
				HIT(sol1, cx,cy,cz, cx/r,0,cz/r, -1,-1, "cylside 1");
			}
			cy = MRATY(sol2);
			if(cy > -h && cy < h) {
				cx = MRATX(sol2);
				cz = MRATZ(sol2);
				HIT(sol2, cx,cy,cz, cx/r,0,cz/r, -1,-1, "cylside 2");
			}
		}
	}
',

# For cone, this is most difficult. We have
# sqrt(
#	((1-r)t_r1.x + r t_r2.x)**2 +
#	((1-r)t_r1.z + r t_r2.z)**2
# ) == radius*( -( (1-r)t_r1.y + r t_r2.y )/(2*h)+0.5)
# == radius * ( -( r*(t_r2.y - t_r1.y) + t_r1.y )/(2*h)+0.5)
# == radius * ( -r*(t_r2.y-t_r1.y)/(2*h) + 0.5 - t_r1.y/(2*h))

#
# Other side: r*r*(
Cone => '
	float h = $f(height)/2; /* pos and neg dir. */
	float y = h;
	float r = $f(bottomRadius);
	float dx = t_r2.x-t_r1.x; float dz = t_r2.z-t_r1.z;
	float dy = t_r2.y-t_r1.y;
	float a = dx*dx + dz*dz - (r*r*dy*dy/(2*h*2*h));
	float b = 2*(dx*t_r1.x + dz*t_r1.z) +
		2*r*r*dy/(2*h)*(0.5-t_r1.y/(2*h));
	float tmp = (0.5-t_r1.y/(2*h));
	float c = t_r1.x * t_r1.x + t_r1.z * t_r1.z 
		- r*r*tmp*tmp;
	float und;
	b /= a; c /= a;
	und = b*b - 4*c;
	/* 
	printf("CONSOL0: (%f %f %f) (%f %f %f)\n",
		t_r1.x, t_r1.y, t_r1.z, t_r2.x, t_r2.y, t_r2.z);
	printf("CONSOL: (%f %f %f) (%f) (%f %f) (%f)\n",
		dx, dy, dz, a, b, c, und);
	*/
	if(und > 0) { /* HITS the infinite cylinder */
		float sol1 = (-b+sqrt(und))/2;
		float sol2 = (-b-sqrt(und))/2;
		float cy,cx,cz;
		float cy0;
		cy = MRATY(sol1);
		if(cy > -h && cy < h) {
			cx = MRATX(sol1);
			cz = MRATZ(sol1);
			/* XXX Normal */
			HIT(sol1, cx,cy,cz, cx/r,0,cz/r, -1,-1, "conside 1");
		}
		cy0 = cy;
		cy = MRATY(sol2);
		if(cy > -h && cy < h) {
			cx = MRATX(sol2);
			cz = MRATZ(sol2);
			HIT(sol2, cx,cy,cz, cx/r,0,cz/r, -1,-1, "conside 2");
		}
		/*
		printf("CONSOLV: (%f %f) (%f %f)\n", sol1, sol2,cy0,cy);
		*/
	}
	if(!YEQ) {
		float yrat0 = YRAT(-y);
		if(TRAT(yrat0)) {
			float cx = MRATX(yrat0);
			float cz = MRATZ(yrat0);
			if(r*r > cx*cx + cz*cz) {
				HIT(yrat0, cx, -y, cz, 0, -1, 0, -1, -1, "conbot");
			}
		}
	}
',

ElevationGrid => ( '
		$mk_polyrep();
		render_ray_polyrep(this_, 
			0, NULL
		);
'),

Extrusion => ( '
		$mk_polyrep();
		render_ray_polyrep(this_, 
			0, NULL
		);
'),

IndexedFaceSet => '
		struct SFColor *points; int npoints;
		$fv(coord, points, get3, &npoints);
		$mk_polyrep();
		render_ray_polyrep(this_, 
			npoints, points
		);
',

);

#####################################################################3
#####################################################################3
#####################################################################3
#
# GenPolyRep
#  code for generating internal polygonal representations
#  of some nodes (ElevationGrid, Extrusion and IndexedFaceSet)
#
#


# In one sense, we could just plot the polygons here and be done
# with it -- displaylists would speed it up.
#
# However, doing this in a device-independent fashion will help
# us a *lot* in porting to some other 3D api.
%GenPolyRepC = (
# ElevationGrid = 2 triangles per each face.
# No color or normal support yet
ElevationGrid => '
		int x,z;
		int nx = $f(xDimension);
		float xs = $f(xSpacing);
		int nz = $f(zDimension);
		float zs = $f(zSpacing);
		float *f = $f(height);
		float a[3],b[3];
		int *cindex; 
		float *coord;
		int ntri = 2 * (nx-1) * (nz-1);
		int triind;
		int nf = $f_n(height);
		struct VRML_PolyRep *rep_ = this_->_intern;
		rep_->ntri = ntri;
		printf("Gen elevgrid %d %d %d\n", ntri, nx, nz);
		if(nf != nx * nz) {
			die("Elevationgrid: too many / too few: %d %d %d\n",
				nf, nx, nz);
		}
		cindex = rep_->cindex = malloc(sizeof(*(rep_->cindex))*3*(ntri));
		coord = rep_->coord = malloc(sizeof(*(rep_->coord))*nx*nz*3);
		/* Flat */
		rep_->normal = malloc(sizeof(*(rep_->normal))*3*ntri);
		rep_->norindex = malloc(sizeof(*(rep_->norindex))*3*ntri);
		/* Prepare the coordinates */
		for(x=0; x<nx; x++) {
		 for(z=0; z<nz; z++) {
		  float h = f[x+z*nx];
		  coord[(x+z*nx)*3+0] = x*xs;
		  coord[(x+z*nx)*3+1] = h;
		  coord[(x+z*nx)*3+2] = z*zs;
		 }
		}
		triind = 0;
		for(x=0; x<nx-1; x++) {
		 for(z=0; z<nz-1; z++) {
		  /* 1: */
		  cindex[triind*3+0] = x+z*nx;
		  cindex[triind*3+1] = x+(z+1)*nx;
		  cindex[triind*3+2] = (x+1)+z*nx;
		rep_->norindex[triind*3+0] = triind;
		rep_->norindex[triind*3+1] = triind;
		rep_->norindex[triind*3+2] = triind;
		  triind ++;
		  /* 2: */
		  cindex[triind*3+0] = x+(z+1)*nx;
		  cindex[triind*3+1] = (x+1)+(z+1)*nx;
		  cindex[triind*3+2] = (x+1)+z*nx;
		rep_->norindex[triind*3+0] = triind;
		rep_->norindex[triind*3+1] = triind;
		rep_->norindex[triind*3+2] = triind;
		  triind ++; 
		 }
		}
		calc_poly_normals_flat(rep_);
	',

# Extrusion => 2 triangles per each extrusion step (like elevgrid..)
# XXX Do begin&end caps
Extrusion => '
		int nspi = $f_n(spine);
		int nsec = $f_n(crossSection);
		int nori = $f_n(orientation);
		int nsca = $f_n(scale);
		int ntri = 2 * (nspi-1) * (nsec-1);
		int spi,sec;
		int triind;
		int closed = 0;
		float spxlen,spylen,spzlen;
		int *cindex;
		float *coord;
		struct pt spm1,spc,spp1,spcp,spy,spz,spoz,spx;
		struct VRML_PolyRep *rep_ = this_->_intern;
		struct SFColor *spine = $f(spine);
		rep_->ntri = ntri;
		cindex = rep_->cindex = malloc(sizeof(*(rep_->cindex))*3*(ntri));
		coord = rep_->coord = malloc(sizeof(*(rep_->coord))*nspi*nsec*3);
		/* Flat */
		rep_->normal = malloc(sizeof(*(rep_->normal))*3*ntri);
		rep_->norindex = malloc(sizeof(*(rep_->norindex))*3*ntri);
		/* Coordinates: find first non-collinear */
		if(spine[0].c[0] == spine[nspi-1].c[0] &&
		   spine[0].c[1] == spine[nspi-1].c[1] &&
		   spine[0].c[2] == spine[nspi-1].c[2]) 
		   	closed = 1;
		/* Special-case, always find entire-collinear */
		if(nspi < 3) {
			die("Collinear spine :( :( :(");
		}
		/* Find first non-zero cross product */
		for(spi = 0; spi<nspi; spi++) {
			if(spi==0) {
				if(closed) {
					VEC_FROM_CDIFF(spine[1],spine[nspi-2], spy);
					VEC_FROM_CDIFF(spine[1],spine[0], spp1);
					VEC_FROM_CDIFF(spine[nspi-2],spine[0], spm1);
				} else {
					VEC_FROM_CDIFF(spine[1],spine[0], spy);
					VEC_FROM_CDIFF(spine[0],spine[1], spm1);
					VEC_FROM_CDIFF(spine[2],spine[1], spp1);
				}
				VECCP(spp1,spm1,spz);
				if(APPROX(VECSQ(spz),0)) {
					double ptlen,cplen,rangle;

					/* Ok, this is where it gets tough...
					 * the first two vecs are collinear */
				 	int j;
					for(j=1; j<nspi-1; j++) {
						VEC_FROM_CDIFF(spine[j-1],spine[j], spm1);
						VEC_FROM_CDIFF(spine[j+1],spine[j], spp1);
						VECCP(spp1,spm1,spz);
						if(!APPROX(VECSQ(spz),0)) 
						  goto got_nz;
					}
					/* Even worse: the whole spine is
					 * linear. Why do they keep doing that!? 
					 */	
					/* Find y -> spp1 */
					spylen = 1/sqrt(VECSQ(spy)); VECSCALE(spy, spylen);
					spzlen = 1/sqrt(VECSQ(spm1)); VECSCALE(spm1, spzlen);
					/* Now, the rotation from (0 1 0) to
					 * spy is the key -- XXX Check
					 * whether we do it right.. */
					VECCP(spy,spz,spp1);
					ptlen = VECPT(spy,spz);
					cplen = sqrt(VECSQ(spp1));
					if(APPROX(cplen,0)) {
						spz.x = 0; spz.y = 0;
						spz.z = 1; goto got_nz;
					}
					VECSCALE(spp1, 1/cplen);
					rangle = atan2(ptlen,cplen);
					spz.x = 
					spz.y = 
					spz.z = spp1.z + 
						(1-spp1.z) * 1; /* cosZZ */
						
					
					die("Collinear spine");
					got_nz:; /* Its all right */
				}
			} else if(spi==nspi-1) {
				if(closed) {
					VEC_FROM_CDIFF(spine[1],spine[nspi-2], spy);
					VEC_FROM_CDIFF(spine[1],spine[0], spp1);
					VEC_FROM_CDIFF(spine[nspi-2],spine[0], spm1);
				} else {
					VEC_FROM_CDIFF(spine[nspi-1],spine[nspi-2], spy);
					VEC_FROM_CDIFF(spine[nspi-3],spine[nspi-2], spm1);
					VEC_FROM_CDIFF(spine[nspi-1],spine[nspi-2], spp1);
				}
				VECCP(spp1,spm1,spz);
			} else {
				VEC_FROM_CDIFF(spine[spi+1],spine[spi-1], spy);
				VEC_FROM_CDIFF(spine[spi-1],spine[spi], spm1);
				VEC_FROM_CDIFF(spine[spi+1],spine[spi], spp1);
				VECCP(spp1,spm1,spz);
			}
			if(APPROX(VECSQ(spz),0)) {
				spz = spoz;
			}
			VECCP(spy,spz,spx);
			spylen = 1/sqrt(VECSQ(spy)); VECSCALE(spy, spylen);
			spzlen = 1/sqrt(VECSQ(spz)); VECSCALE(spz, spzlen);
			spxlen = 1/sqrt(VECSQ(spx)); VECSCALE(spx, spxlen);
			/* Now we have spy and spz in every case */
			for(sec = 0; sec<nsec; sec++) {
				struct pt point;
				float ptx = $f(crossSection,sec).c[0];
				float ptz = $f(crossSection,sec).c[1];
				if(nsca) {
					int sca = (nsca==1 ? 0 : spi);
					ptx *= $f(scale,sca).c[0];
					ptz *= $f(scale,sca).c[1];
				}
				if(nori) {
					int ori = (nori==1 ? 0 : spi);
					/* XXX */
					point.x = ptx;
					point.y = 0; 
					point.z = ptz;
				} else {
					point.x = ptx;
					point.y = 0; 
					point.z = ptz;
				}
			   coord[(sec+spi*nsec)*3+0] = 
			    spx.x * point.x + spy.x * point.y + spz.x * point.z
			    + $f(spine,spi).c[0];
			   coord[(sec+spi*nsec)*3+1] = 
			    spx.y * point.x + spy.y * point.y + spz.y * point.z
			    + $f(spine,spi).c[1];
			   coord[(sec+spi*nsec)*3+2] = 
			    spx.z * point.x + spy.z * point.y + spz.z * point.z
			    + $f(spine,spi).c[2];
			}
			spoz = spz;
		}
		triind = 0;
		{
		int x,z; int nx=nsec; int nz=nspi;
		for(x=0; x<nx-1; x++) {
		 for(z=0; z<nz-1; z++) {
		  /* 1: */
		  cindex[triind*3+0] = x+z*nx;
		  cindex[triind*3+1] = x+(z+1)*nx;
		  cindex[triind*3+2] = (x+1)+z*nx;
		rep_->norindex[triind*3+0] = triind;
		rep_->norindex[triind*3+1] = triind;
		rep_->norindex[triind*3+2] = triind;
		  triind ++;
		  /* 2: */
		  cindex[triind*3+0] = x+(z+1)*nx;
		  cindex[triind*3+1] = (x+1)+(z+1)*nx;
		  cindex[triind*3+2] = (x+1)+z*nx;
		rep_->norindex[triind*3+0] = triind;
		rep_->norindex[triind*3+1] = triind;
		rep_->norindex[triind*3+2] = triind;
		  triind ++; 
		 }
		}
		}
		calc_poly_normals_flat(rep_);
',
IndexedFaceSet => '
	int i;
	int cin = $f_n(coordIndex);
	int cpv = $f(colorPerVertex);
	/* int npv = xf(normalPerVertex); */
	int ntri = 0;
	int nvert = 0;
	struct SFColor *c1,*c2,*c3;
	float a[3]; float b[3];
	struct SFColor *points; int npoints;
	struct SFColor *normals; int nnormals=0;
	struct VRML_PolyRep *rep_ = this_->_intern;
	int *cindex;
	$fv(coord, points, get3, &npoints);
	$fv_null(normal, normals, get3, &nnormals);
	
	for(i=0; i<cin; i++) {
		if($f(coordIndex,i) == -1) {
			if(nvert < 3) {
				die("Too few vertices in indexedfaceset poly");
			}
			ntri += nvert-2;
			nvert = 0;
		} else {
			nvert ++;
		}
	}
	if(nvert>2) {ntri += nvert-2;}
	cindex = rep_->cindex = malloc(sizeof(*(rep_->cindex))*3*(ntri));
	rep_->ntri = ntri;
	if(!nnormals) {
		/* We have to generate -- do flat only for now */
		rep_->normal = malloc(sizeof(*(rep_->normal))*3*ntri);
		rep_->norindex = malloc(sizeof(*(rep_->norindex))*3*ntri);
	} else {
		rep_->normal = NULL;
		rep_->norindex = NULL;
	}
	/* color = NULL; coord = NULL; normal = NULL;
		colindex = NULL; norindex = NULL;
	*/
	if(!$f(convex)) {
		die("AAAAARGHHH!!!  Non-convex polygons! Help!");
		/* XXX Fixme using gluNewTess, gluTessVertex et al */
	} else {
		int initind=-1;
		int lastind=-1;
		int triind = 0;
		for(i=0; i<cin; i++) {
			if($f(coordIndex,i) == -1) {
				initind=-1;
				lastind=-1;
			} else {
				if(initind == -1) {
					initind = $f(coordIndex,i);
				} else if(lastind == -1) {
					lastind = $f(coordIndex,i);
				} else {
					
					cindex[triind*3+0] = initind;
					cindex[triind*3+1] = lastind;
					cindex[triind*3+2] = $f(coordIndex,i);
					if(rep_->normal) {
						c1 = &(points[initind]);
						c2 = &(points[lastind]); 
						c3 = &(points[$f(coordIndex,i)]);
						a[0] = c2->c[0] - c1->c[0];
						a[1] = c2->c[1] - c1->c[1];
						a[2] = c2->c[2] - c1->c[2];
						b[0] = c3->c[0] - c1->c[0];
						b[1] = c3->c[1] - c1->c[1];
						b[2] = c3->c[2] - c1->c[2];
						rep_->normal[triind*3+0] =
							a[1]*b[2] - b[1]*a[2];
						rep_->normal[triind*3+1] =
							-(a[0]*b[2] - b[0]*a[2]);
						rep_->normal[triind*3+2] =
							a[0]*b[1] - b[0]*a[1];
						rep_->norindex[triind*3+0] = triind;
						rep_->norindex[triind*3+1] = triind;
						rep_->norindex[triind*3+2] = triind;
					}
					lastind = $f(coordIndex,i);
					triind++;
				}
			}
		}
	}
',
);

######################################################################
######################################################################
######################################################################
#
# Get3
#  get a coordinate / color / normal array from the node.
#

%Get3C = (
Coordinate => '
	*n = $f_n(point); 
	return $f(point);
',
Color => '
	*n = $f_n(color); 
	return $f(color);
',
Normal => '
	*n = $f_n(vector);
	return $f(vector);
'
);

######################################################################
######################################################################
######################################################################
#
# Generation
#  Functions for generating the code
#


{
	my %AllNodes = (%RendC, %PrepC, %FinC, %ChildC, %Get3C, %LightC);
	@NodeTypes = keys %AllNodes;
}

sub assgn_m {
	my($f, $l) = @_;
	return ((join '',map {"m[$_] = ".getf(Material, $f, $_).";"} 0..2).
		"m[3] = $l;");
}

# XXX Might we need separate fields for separate structs?
sub getf {
	my ($t, $f, @l) = @_;
	my $type = $VRML::Nodes{$t}{FieldTypes}{$f};
	if($type eq "") {
		die("Invalid type $t $f '$type'");
	}
	return "VRML::Field::$type"->cget("(this_->$f)",@l);
}

sub getfn {
	my($t, $f) = @_;
	my $type = $VRML::Nodes{$t}{FieldTypes}{$f};
	return "VRML::Field::$type"->cgetn("(this_->$f)");
}

# XXX Code copy :(
sub fvirt {
	my($t, $f, $ret, $v, @a) = @_;
	# Die if not exists
	my $type = $VRML::Nodes{$t}{FieldTypes}{$f};
	if($type ne "SFNode") {
		die("Fvirt must have SFNode");
	}
	if($ret) {$ret = "$ret = ";}
	return "if(this_->$f) {
		  if(!(*(struct VRML_Virt **)(this_->$f))->$v) {
		  	die(\"NULL METHOD $t $f $v\");
		  }
		  $ret ((*(struct VRML_Virt **)(this_->$f))->$v(this_->$f,
		    ".(join ',',@a).")) ;}
 	  else { (die(\"NULL FIELD $t $f $a\"));}";
}

sub fvirt_null {
	my($t, $f, $ret, $v, @a) = @_;
	# Die if not exists
	my $type = $VRML::Nodes{$t}{FieldTypes}{$f};
	if($type ne "SFNode") {
		die("Fvirt must have SFNode");
	}
	if($ret) {$ret = "$ret = ";}
	return "if(this_->$f) {
		  if(!(*(struct VRML_Virt **)(this_->$f))->$v) {
		  	die(\"NULL METHOD $t $f $v\");
		  }
		  $ret ((*(struct VRML_Virt **)(this_->$f))->$v(this_->$f,
		    ".(join ',',@a).")) ;
		}";
}


sub fgetfnvirt_n {
	my($n, $ret, $v, @a) = @_;
	if($ret) {$ret = "$ret = ";}
	return "if($n) {
	         if(!(*(struct VRML_Virt **)n)->$v) {
		  	die(\"NULL METHOD $n $ret $v\");
		 }
		 $ret ((*(struct VRML_Virt **)($n))->$v($n,
		    ".(join ',',@a).")) ;}
	"
}

sub rend_geom {
	return $_[0];
}

sub gen_struct {
	my($name,$node) = @_;
	my @f = keys %{$node->{FieldTypes}};
	my $nf = scalar @f;
	# /* Store actual point etc. later */
	my $s = "struct VRML_$name {struct VRML_Virt *v;int _sens;int _hit; 
		int _change; int _dlchange; GLuint _dlist; int _dl2change; GLuint _dl2ist; void *_intern; \n";
	my $o = "
void *
get_${name}_offsets(p)
	SV *p;
CODE:
	int *ptr_;
	SvGROW(p,($nf+1)*sizeof(int));
	SvCUR_set(p,($nf+1)*sizeof(int));
	ptr_ = (int *)SvPV(p,na);
";
	my $p = " {
		my \$s = '';
		my \$v = get_${name}_offsets(\$s);
		\@{\$n->{$name}{Offs}}{".(join ',',map {"\"$_\""} @f,'_end_')."} =
			unpack(\"i*\",\$s);
		\$n->{$name}{Virt} = \$v;
 }
	";
	for(@f) {
		my $cty = "VRML::Field::$node->{FieldTypes}{$_}"->ctype($_);
		$s .= "\t$cty;\n";
		$o .= "\t*ptr_++ = offsetof(struct VRML_$name, $_);\n";
	}
	$o .= "\t*ptr_++ = sizeof(struct VRML_$name);\n";
	$o .= "RETVAL=&(virt_${name});
	if(verbose) printf(\"$name virtual: %d\\n\", RETVAL);
OUTPUT:
	RETVAL
";
	$s .= "};\n";
	return ($s,$o,$p);
}

#########################################################
sub get_offsf {
	my($f) = @_;
	my ($ct) = ("VRML::Field::$_")->ctype("*ptr_");
	my ($ctp) = ("VRML::Field::$_")->ctype("*");
	my ($c) = ("VRML::Field::$_")->cfunc("(*ptr_)", "sv_");
	my ($ca) = ("VRML::Field::$_")->calloc("(*ptr_)");
	my ($cf) = ("VRML::Field::$_")->cfree("(*ptr_)");
	return "

void 
set_offs_$f(ptr,offs,sv_)
	void *ptr
	int offs
	SV *sv_
CODE:
	$ct = ($ctp)(((char *)ptr)+offs);
	{struct VRML_Box *p;
	 p = ptr;
	 p->_change ++;
	}
	$c


void 
alloc_offs_$f(ptr,offs)
	void *ptr
	int offs
CODE:
	$ct = ($ctp)(((char *)ptr)+offs);
	$ca

void
free_offs_$f(ptr,offs)
	void *ptr
	int offs
CODE:
	$ct = ($ctp)(((char *)ptr)+offs);
	$cf

"
}
#######################################################

sub get_rendfunc {
	my($n) = @_;
	print "RENDF $n ";
	# XXX
	my @f = qw/Prep Rend Child Fin RendRay GenPolyRep Light Get3/;
	my $f;
	my $v = "
static struct VRML_Virt virt_${n} = { ".
	(join ',',map {${$_."C"}{$n} ? "${n}_$_" : "NULL"} @f).
",\"$n\"};";
	for(@f) {
		my $c =${$_."C"}{$n};
		next if !defined $c;
		print "$_ (",length($c),") ";
		# Substitute field gets
		$c =~ s/\$f\(([^)]*)\)/getf($n,split ',',$1)/ge;
		$c =~ s/\$f_n\(([^)]*)\)/getfn($n,split ',',$1)/ge;
		$c =~ s/\$fv\(([^)]*)\)/fvirt($n,split ',',$1)/ge;
		$c =~ s/\$fv_null\(([^)]*)\)/fvirt_null($n,split ',',$1)/ge;
		$c =~ s/\$mk_polyrep\(\)/if(!this_->_intern || 
			this_->_change != ((struct VRML_PolyRep *)this_->_intern)->_change)
				regen_polyrep(this_);/g;
		$c =~ s/\$start(_|)list\(\)/
		        if(!this_->_dlist) {
				this_->_dlist = glGenLists(1);
			}
			if(this_->_dlchange != this_->_change) {
				glNewList(this_->_dlist,GL_COMPILE_AND_EXECUTE);
				this_->_dlchange = this_->_change;
			} else {
				glCallList(this_->_dlist); return;
			}/g;
		$c =~ s/\$end(_|)list\(\)/
			glEndList()
			/g;
		$c =~ s/\$start(_|)list2\(\)/
		        if(!this_->_dl2ist) {
				this_->_dl2ist = glGenLists(1);
			}
			if(this_->_dl2change != this_->_change) {
				glNewList(this_->_dl2ist,GL_COMPILE_AND_EXECUTE);
				this_->_dl2change = this_->_change;
			} else {
				glCallList(this_->_dl2ist); return;
			}/g;
		$c =~ s/\$end(_|)list2\(\)/
			glEndList()
			/g;
		if($_ eq "Get3") {
			$f .= "struct SFColor *${n}_$_(void *nod_,int *n)";
		} else {
			$f .= "void ${n}_$_(void *nod_)";
		}
		$f .= "{ /* GENERATED FROM HASH ${$_}C, MEMBER $n */
			struct VRML_$n *this_ = (struct VRML_$n *)nod_;
			{$c}
			}";
	}
	print "\n";
	return ($f,$v);
}

######################################################################
######################################################################
######################################################################
#
# gen - the main function. this contains much verbatim code
#
#

sub gen {
	for(@VRML::Fields) {
		push @str, ("VRML::Field::$_")->cstruct;
		push @xsfn, get_offsf($_);
	}
	for(@NodeTypes) {
		my $no = $VRML::Nodes{$_}; 
		my($str, $offs, $perl) = gen_struct($_, $no);
		push @str, $str;
		push @xsfn, $offs;
		push @poffsfn, $perl;
		my($f, $vstru) = get_rendfunc($_);
		push @func, $f;
		push @vstruc, $vstru;
	}
	open XS, ">VRMLFunc.xs";
	print XS '
/* VRMLFunc.c generated by VRMLC.pm. DO NOT MODIFY, MODIFY VRMLC.pm INSTEAD */

/* Code here comes almost verbatim from VRMLC.pm */

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include <math.h>

#include <GL/gl.h>
#include <GL/glu.h>
#include <GL/glx.h>

#include "OpenGL/OpenGL.m"

#define offset_of(p_type,field) ((unsigned int)(&(((p_type)NULL)->field)-NULL))

#define TC(a,b) glTexCoord2f(a,b)

D_OPENGL;


/* Rearrange to take advantage of headlight when off */
int curlight = 0;
int nlightcodes = 7;
int lightcode[7] = {
	GL_LIGHT1,
	GL_LIGHT2,
	GL_LIGHT3,
	GL_LIGHT4,
	GL_LIGHT5,
	GL_LIGHT6,
	GL_LIGHT7,
};
int nextlight() {
	if(curlight == nlightcodes) { return -1; }
	return lightcode[curlight++];
}

struct VRML_Virt {
	void (*prep)(void *);
	void (*rend)(void *); 
	void (*children)(void *);
	void (*fin)(void *);
	void (*rendray)(void *);
	void (*mkpolyrep)(void *);
	void (*light)(void *);
	/* And get float coordinates : Coordinate, Color */
	/* XXX Relies on MFColor repr.. */
	struct SFColor *(*get3)(void *, int *); /* Number in int */
	char *name;
};

/* Internal representation of IndexedFaceSet, Extrusion & ElevationGrid:
 * set of triangles.
 * done so that we get rid of concave polygons etc.
 */
struct VRML_PolyRep { /* Currently a bit wasteful, because copying */
	int _change;
	int ntri; /* number of triangles */
	int *cindex;   /* triples (per triangle) */
	float *coord; /* triples (per point) */
	int *colindex;   /* triples (per triangle) */
	float *color; /* triples or null */
	int *norindex;
	float *normal; /* triples or null */
};

';
	print XS join '',@str;
	print XS '

int verbose;

int reverse_trans;
int render_vp; 
int render_geom;
int render_light;
int render_sensitive;

int horiz_div; int vert_div;

int cur_hits=0;

/* These two points define a ray in window coordinates */

struct pt {GLdouble x,y,z;};

struct pt r1 = {0,0,-1},r2 = {0,0,0};
struct pt t_r1,t_r2; /* transformed ray */
void *hypersensitive; int hyperhit;
struct pt hyper_r1,hyper_r2; /* Transformed ray for the hypersensitive node */

GLint viewport[4] = {-1,-1,2,2};

/* These three points define 1. hitpoint 2., 3. two different tangents
 * of the surface at hitpoint (to get transformation correctly */ 

/* All in window coordinates */

struct pt hp, ht1, ht2;
double hpdist; /* distance in ray: 0 = r1, 1 = r2, 2 = 2*r2-r1... */

struct currayhit {
void *node; /* What node hit at that distance? */
GLdouble modelMatrix[16]; /* What the matrices were at that node */
GLdouble projMatrix[16];
} rh,rph;
 /* used to test new hits */

/* defines for raycasting: */
#define APPROX(a,b) (fabs(a-b)<0.00000001)
#define XEQ (APPROX(t_r1.x,t_r2.x))
#define YEQ (APPROX(t_r1.y,t_r2.y))
#define ZEQ (APPROX(t_r1.z,t_r2.z))
/* xrat(a) = ratio to reach coordinate a on axis x */
#define XRAT(a) (((a)-t_r1.x)/(t_r2.x-t_r1.x))
#define YRAT(a) (((a)-t_r1.y)/(t_r2.y-t_r1.y))
#define ZRAT(a) (((a)-t_r1.z)/(t_r2.z-t_r1.z))
/* mratx(r) = x-coordinate gotten by multiplying by given ratio */
#define MRATX(a) (t_r1.x + (a)*(t_r2.x-t_r1.x))
#define MRATY(a) (t_r1.y + (a)*(t_r2.y-t_r1.y))
#define MRATZ(a) (t_r1.z + (a)*(t_r2.z-t_r1.z))
/* trat: test if a ratio is reasonable */
#undef TRAT
#define TRAT(a) 1
#undef TRAT
#define TRAT(a) ((a) > 0 && ((a) < hpdist || hpdist < 0))

#define VECSQ(a) VECPT(a,a)
#define VECPT(a,b) ((a).x*(b).x + (a).y*(b).y + (a).z*(b).z)
#define VECDIFF(a,b,c) {(c).x = (a).x-(b).x;(c).y = (a).y-(b).y;(c).z = (a).z-(b).z;}
#define VEC_FROM_CDIFF(a,b,r) {(r).x = (a).c[0]-(b).c[0];(r).y = (a).c[1]-(b).c[1];(r).z = (a).c[2]-(b).c[2];}
#define VECCP(a,b,c) {(c).x = (a).y*(b).z-(b).y*(a).z; (c).y = -((a).x*(b).z-(b).x*(a).z); (c).z = (a).x*(b).y-(b).x*(a).y;}
#define VECSCALE(a,c) {(a).x *= c; (a).y *= c; (a).z *= c;}
#define HIT rayhit

/* Sub, rather than big macro... */
void rayhit(float rat, float cx,float cy,float cz, float nx,float ny,float nz, 
float tx,float ty, char *descr)  {
	GLdouble modelMatrix[16];
	GLdouble projMatrix[16];
	GLdouble wx, wy, wz;
	/* Real rat-testing */
	if(verbose) printf("RAY HIT %s! %f (%f %f %f) (%f %f %f)\nR: (%f %f %f) (%f %f %f)\n",
		descr, rat,cx,cy,cz,nx,ny,nz,
		t_r1.x, t_r1.y, t_r1.z,
		t_r2.x, t_r2.y, t_r2.z
		);
	if(rat<0 || (rat>hpdist && hpdist >= 0)) {
		return;
	}
	glGetDoublev(GL_MODELVIEW_MATRIX, modelMatrix);
	glGetDoublev(GL_PROJECTION_MATRIX, projMatrix);
	gluProject(cx,cy,cz, modelMatrix, projMatrix, viewport,
		&hp.x, &hp.y, &hp.z);
	hpdist = rat;
	rh=rph;
}

/* Call this when modelview and projection modified */
void upd_ray() {
	GLdouble modelMatrix[16];
	GLdouble projMatrix[16];
	glGetDoublev(GL_MODELVIEW_MATRIX, modelMatrix);
	glGetDoublev(GL_PROJECTION_MATRIX, projMatrix);
	gluUnProject(r1.x,r1.y,r1.z,modelMatrix,projMatrix,viewport,
		&t_r1.x,&t_r1.y,&t_r1.z);
	gluUnProject(r2.x,r2.y,r2.z,modelMatrix,projMatrix,viewport,
		&t_r2.x,&t_r2.y,&t_r2.z);
/*	printf("Upd_ray: (%f %f %f)->(%f %f %f) == (%f %f %f)->(%f %f %f)\n",
		r1.x,r1.y,r1.z,r2.x,r2.y,r2.z,
		t_r1.x,t_r1.y,t_r1.z,t_r2.x,t_r2.y,t_r2.z);
*/
}


void *what_vp;
int render_anything; /* Turned off when we hit the viewpoint */
void render_node(void *node);
void render_polyrep(void *node, 
	int npoints, struct SFColor *points,
	int ncolors, struct SFColor *colors,
	int nnormals, struct SFColor *normals);
void regen_polyrep(void *node) ;
void calc_poly_normals_flat(struct VRML_PolyRep *rep);
void render_ray_polyrep(void *node,
	int npoints, struct SFColor *points);

/*********************************************************************
 * Code here is generated from the hashes in VRMLC.pm and VRMLRend.pm
 */
	';

#######################################################j


	print XS join '',@func;
	print XS join '',@vstruc;
#######################################################
	print XS <<'ENDHERE'

/*********************************************************************
 * Code here again comes almost verbatim from VRMLC.pm 
 */

/*********************************************************************
 *********************************************************************
 *
 * render_polyrep : render one of the internal polygonal representations
 * for some nodes
 */
 

void render_polyrep(void *node, 
	int npoints, struct SFColor *points,
	int ncolors, struct SFColor *colors,
	int nnormals, struct SFColor *normals)
{
	struct VRML_Virt *v;
	struct VRML_Box *p;
	struct VRML_PolyRep *r;
	int i;
	int pt;
	int pti;
	int hasc;
	v = *(struct VRML_Virt **)node;
	p = node;
	r = p->_intern;
/*	printf("Render polyrep %d '%s' (%d %d): %d\n",node,v->name, 
		p->_change, r->_change, r->ntri);
 */
	glBegin(GL_TRIANGLES);
	hasc = (ncolors || r->color);
	if(hasc) {
		glEnable(GL_COLOR_MATERIAL);
	}
	for(i=0; i<r->ntri*3; i++) {
		int nori = i;
		int coli = i;
		int ind = r->cindex[i];
		GLfloat color[4];
		if(r->norindex) {nori = r->norindex[i];}
		else nori = ind;
		if(r->colindex) {coli = r->colindex[i];}
		else coli = ind;
		if(nnormals) {
			if(nori >= nnormals) {
				warn("Too large normal index -- help??");
			}
			glNormal3fv(normals[nori].c);
		} else if(r->normal) {
			glNormal3fv(r->normal+3*nori);
		}
		if(hasc) {
			if(ncolors) {
				/* ColorMaterial -> these set Material too */
				glColor3fv(colors[coli].c);
			} else if(r->color) {
				glColor3fv(r->color+3*coli);
			}
		}
		if(points) {
			glVertex3fv(points[ind].c);
		} else if(r->coord) {
			glVertex3fv(r->coord+3*ind);
		}
	}
	if(hasc) {
		glDisable(GL_COLOR_MATERIAL);
	}
	glEnd();
}

/*********************************************************************
 *********************************************************************
 *
 * render_ray_polyrep : get intersections of a ray with one of the
 * polygonal representations
 */

void render_ray_polyrep(void *node,
	int npoints, struct SFColor *points)
{
	struct VRML_Virt *v;
	struct VRML_Box *p;
	struct VRML_PolyRep *r;
	int i;
	int pt;
	int pti;
	float *point[3];
	struct pt v1, v2, v3;
	struct pt x1, x2, x3;
	struct pt ray;
	float pt1, pt2, pt3;
	struct pt hitpoint;
	float tmp1,tmp2,tmp3;
	float v1len, v2len, v3len;
	float v12pt;
	ray.x = t_r2.x - t_r1.x;
	ray.y = t_r2.y - t_r1.y;
	ray.z = t_r2.z - t_r1.z;
	v = *(struct VRML_Virt **)node;
	p = node;
	r = p->_intern;
/*	printf("Render polyrepray %d '%s' (%d %d): %d\n",node,v->name, 
		p->_change, r->_change, r->ntri);
 */
	for(i=0; i<r->ntri; i++) {
		float len;
		for(pt = 0; pt<3; pt++) {
			int ind = r->cindex[i*3+pt];
			if(points) {
				point[pt] = (points[ind].c);
			} else if(r->coord) {
				point[pt] = (r->coord+3*ind);
			}
		}
		/* First we need to project our point to the surface */
		/* Poss. 1: */
		/* Solve s1xs2 dot ((1-r)r1 + r r2 - pt0)  ==  0 */
		/* I.e. calculate s1xs2 and ... */
		v1.x = point[1][0] - point[0][0];
		v1.y = point[1][1] - point[0][1];
		v1.z = point[1][2] - point[0][2];
		v2.x = point[2][0] - point[0][0];
		v2.y = point[2][1] - point[0][1];
		v2.z = point[2][2] - point[0][2];
		v1len = sqrt(VECSQ(v1)); VECSCALE(v1, 1/v1len);
		v2len = sqrt(VECSQ(v2)); VECSCALE(v2, 1/v2len);
		v12pt = VECPT(v1,v2);
		/* v3 is our normal to the surface */
		VECCP(v1,v2,v3);
		v3len = sqrt(VECSQ(v3)); VECSCALE(v3, 1/v3len);
		pt1 = VECPT(t_r1,v3);
		pt2 = VECPT(t_r2,v3);
		pt3 = v3.x * point[0][0] + v3.y * point[0][1] + 
			v3.z * point[0][2]; 
		/* Now we have (1-r)pt1 + r pt2 - pt3 = 0
		 * r * (pt1 - pt2) = pt1 - pt3
		 */
		 tmp1 = pt1-pt2;
		 if(!APPROX(tmp1,0)) {
		 	float ra, rb;
			float k,l;
			struct pt p0h;
		 	tmp2 = (pt1-pt3) / (pt1-pt2);
			hitpoint.x = MRATX(tmp2);
			hitpoint.y = MRATY(tmp2);
			hitpoint.z = MRATZ(tmp2);
			/* Now we want to see if we are in the triangle */
			/* Projections to the two triangle sides */
			p0h.x = hitpoint.x - point[0][0];
			p0h.y = hitpoint.y - point[0][1];
			p0h.z = hitpoint.z - point[0][2];
			ra = VECPT(v1, p0h);
			if(ra < 0) {continue;}
			rb = VECPT(v2, p0h);
			if(rb < 0) {continue;}
			/* Now, the condition for the point to
			 * be inside 
			 * (ka + lb = p)
			 * (k + l b.a = p.a)
			 * (k b.a + l = p.b)
			 * (k - (b.a)**2 k = p.a - (b.a)*p.b)
			 * k = (p.a - (b.a)*(p.b)) / (1-(b.a)**2)
			 */
			 k = (ra - v12pt * rb) / (1-v12pt*v12pt);
			 l = (rb - v12pt * ra) / (1-v12pt*v12pt);
			 k /= v1len; l /= v2len;
			 if(k+l > 1 || k < 0 || l < 0) {
			 	continue;
			 }
			 HIT(tmp2, hitpoint.x,hitpoint.y,hitpoint.z,
			 	v3.x,v3.y,v3.z, -1,-1, "polyrep");
		 }

#ifdef FOOEIFJOESFIJESF
		/* But maybe easier: calc. (ray1->p1) x ray,
		 * (ray1->p2) x ray and (ray1->p3) x ray 
		 * and dot products of these. if sum > -180, ok.
		 * XXX Doesn't give us point/normal easily.
		 */
		v1.x = point[0][0] - t_r1.x;
		v1.y = point[0][1] - t_r1.y;
		v1.z = point[0][2] - t_r1.z;
		v2.x = point[1][0] - t_r1.x;
		v2.y = point[1][1] - t_r1.y;
		v2.z = point[1][2] - t_r1.z;
		v3.x = point[2][0] - t_r1.x;
		v3.y = point[2][1] - t_r1.y;
		v3.z = point[2][2] - t_r1.z;
		VECCP(v1, ray, x1);
		VECCP(v2, ray, x2);
		VECCP(v3, ray, x3);
		len = 1/sqrt(VECSQ(x1)); VECSCALE(x1,len);
		len = 1/sqrt(VECSQ(x2)); VECSCALE(x2,len);
		len = 1/sqrt(VECSQ(x3)); VECSCALE(x3,len);
		pt1 = VECPT(x1,x2);
		pt2 = VECPT(x2,x3);
		pt3 = VECPT(x3,x1);
		/* Now the simple condition: one of the angles 
		if( acos(pt1) + acos(pt2) + acos(pt3)
		*/
#endif FOEIJFOEJFOIEJ
	}
}

void regen_polyrep(void *node) 
{
	struct VRML_Virt *v;
	struct VRML_Box *p;
	struct VRML_PolyRep *r;
	v = *(struct VRML_Virt **)node;
	p = node;
	printf("Regen polyrep %d '%s'\n",node,v->name);
	if(!p->_intern) {
		p->_intern = malloc(sizeof(struct VRML_PolyRep));
		r = p->_intern;
		r->ntri = -1;
		r->cindex = 0; r->coord = 0; r->colindex = 0; r->color = 0;
		r->norindex = 0; r->normal = 0;
	}
	r = p->_intern;
	r->_change = p->_change;
#define FREE_IF_NZ(a) if(a) {free(a); a = 0;}
	FREE_IF_NZ(r->cindex);
	FREE_IF_NZ(r->coord);
	FREE_IF_NZ(r->colindex);
	FREE_IF_NZ(r->color);
	FREE_IF_NZ(r->norindex);
	FREE_IF_NZ(r->normal);
	v->mkpolyrep(node);
}

/* Assuming that norindexes set */
void calc_poly_normals_flat(struct VRML_PolyRep *rep) 
{
	int i;
	float a[3],b[3], *v1,*v2,*v3;
	for(i=0; i<rep->ntri; i++) {
		v1 = rep->coord+3*rep->cindex[i*3+0];
		v2 = rep->coord+3*rep->cindex[i*3+1];
		v3 = rep->coord+3*rep->cindex[i*3+2];
		a[0] = v2[0]-v1[0];
		a[1] = v2[1]-v1[1];
		a[2] = v2[2]-v1[2];
		b[0] = v3[0]-v1[0];
		b[1] = v3[1]-v1[1];
		b[2] = v3[2]-v1[2];
		rep->normal[i*3+0] =
			a[1]*b[2] - b[1]*a[2];
		rep->normal[i*3+1] =
			-(a[0]*b[2] - b[0]*a[2]);
		rep->normal[i*3+2] =
			a[0]*b[1] - b[0]*a[1];
	}
}

/*********************************************************************
 *********************************************************************
 *
 * render_node : call the correct virtual functions to render the node
 * depending on what we are doing right now.
 */

void render_node(void *node) {
	struct VRML_Virt *v;
	struct VRML_Box *p;
	int srg;
	int sch;
	struct currayhit srh;
	if(verbose) printf("Render_node %d\n",node);
	if(!node) {return;}
	v = *(struct VRML_Virt **)node;
	p = node;
	if(verbose) printf("Render_node_v %d\n",v);
	if(verbose) printf("Render_node_v_d \"%s\"\n",v->name);
	if(verbose) printf("Render_node_v_prep %d\n",v->prep);
	if(verbose) printf("Render_node_v_rend %d\n",v->rend);
	if(verbose) printf("Render_node_v_children %d\n",v->children);
	if(verbose) printf("Render_node_v_fin %d\n",v->fin);
	if(render_anything && v->prep) {v->prep(node);
		if(render_sensitive && v == &virt_Transform) { upd_ray(); }
	}
	if(render_anything && render_geom && v->rend) {v->rend(node);}
	if(render_anything && render_light && v->light) {v->light(node);}
	if(render_anything && render_geom && render_sensitive &&
		v->rendray) {v->rendray(node);}
	/* Future optimization: when doing VP/Lights, do only 
	 * that child... further in future: could just calculate
	 * transforms myself..
	 */
	if(render_anything &&
	   render_sensitive &&
	   p->_sens) {
	   	srg = render_geom;
		render_geom = 1;
		cur_hits += glRenderMode(GL_SELECT);
		if(verbose) printf("CH1 %d: %d\n",node, cur_hits, p->_hit);
		glInitNames();
		glPushName(1);
		sch = cur_hits;
		cur_hits = 0;
		/* HP */
		srh = rph;
		rph.node = node;
		glGetDoublev(GL_MODELVIEW_MATRIX, rph.modelMatrix);
		glGetDoublev(GL_PROJECTION_MATRIX, rph.projMatrix);
	}
	if(hypersensitive == node) {
		hyper_r1 = t_r1;
		hyper_r2 = t_r2;
		hyperhit = 1;
	}
	if(render_anything && v->children) {v->children(node);}
	if(render_anything &&
	   render_sensitive &&
	   p->_sens) {
	   	cur_hits += glRenderMode(GL_SELECT);
		if(verbose) printf("CH2 %d: %d\n",node, cur_hits);
		glInitNames();
		glPushName(1);
		/* p->_hit += cur_hits; */
		render_geom = srg;
		cur_hits = sch;
		if(verbose) printf("CH3: %d %d\n",cur_hits, p->_hit);
		/* HP */
		rph = srh;
	}
	if(render_anything && v->fin) {v->fin(node);
		if(render_sensitive && v == &virt_Transform) { upd_ray(); }
	}
}


MODULE = VRML::VRMLFunc PACKAGE = VRML::VRMLFunc

PROTOTYPES: ENABLE

void *
alloc_struct(siz,virt)
	int siz
	void *virt
CODE:
	void *ptr = malloc(siz);
	struct VRML_Box *p = ptr;
	if(verbose) printf("Alloc: %d %d -> %d\n", siz, virt, ptr); 
	*(struct VRML_Virt **)ptr = (struct VRML_Virt *)virt;
	p->_sens = p->_hit = 0;
	p->_intern = 0;
	p->_change = 153;
	p->_dlchange = 0;
	p->_dlist = 0;
	p->_dl2change = 0;
	p->_dl2ist = 0;
	RETVAL=ptr;
OUTPUT:
	RETVAL

void
release_struct(ptr)
	void *ptr
CODE:
	free(ptr); /* COULD BE MEMLEAK IF STUFF LEFT INSIDE */

void
set_sensitive(ptr,sens)
	void *ptr
	int sens
CODE:
	/* Choose box randomly */
	struct VRML_Box *p = ptr;
	p->_sens = sens;

void 
set_hypersensitive(ptr)
	void *ptr
CODE:	
	hypersensitive = ptr;
	hyperhit = 0;

int
get_hyperhit(x1,y1,z1,x2,y2,z2)
	double x1
	double y1
	double z1
	double x2
	double y2
	double z2
CODE:
	if(hyperhit) {
		x1 = hyper_r1.x;
		y1 = hyper_r1.y;
		z1 = hyper_r1.z;
		x2 = hyper_r2.x;
		y2 = hyper_r2.y;
		z2 = hyper_r2.z;
		RETVAL=1;
	} else RETVAL = 0;
OUTPUT:
	RETVAL
	x1
	y1
	z1
	x2
	y2
	z2
	

int
get_hits(ptr)
	void *ptr
CODE:
	struct VRML_Box *p = ptr;
	RETVAL = p->_hit;
	p->_hit = 0;
OUTPUT:
	RETVAL

void
zero_hits(ptr)
	void *ptr
CODE:
	struct VRML_Box *p = ptr;
	p->_hit = 0;

void 
render_verbose(i)
	int i;
CODE:
	verbose=i;

void
render_geom(p)
	void *p
CODE:
	struct VRML_Virt *v;
	if(!p) {
		die("Render_geom null!??");
	}
	v = *(struct VRML_Virt **)p;
	v->rend(p);

void 
render_hier(p,revt,rvp,rgeom,rlight,rsens,wvp)
	void *p
	int revt
	int rvp
	int rgeom
	int rlight
	int rsens
	void *wvp
CODE:
	reverse_trans = revt;
	render_vp = rvp;
	render_geom =  rgeom;
	render_light = rlight;
	render_sensitive = rsens;
	curlight = 0;
	what_vp = wvp;
	render_anything = 1;
	hpdist = -1;
	if(!p) {
		die("Render_hier null!??");
	}
	if(verbose) printf("Render_hier %d %d %d %d %d %d\n", p, revt, rvp, rgeom, rlight, wvp);
	if(render_sensitive) upd_ray();
	render_node(p);
	if(render_sensitive) { /* Get raycasting results */
		if(hpdist >= 0) {
			if(verbose) printf("RAY HIT!\n");
		}
	}

void *
get_rayhit(x,y,z,nx,ny,nz,tx,ty)
	double x
	double y
	double z
	double nx
	double ny
	double nz
	double tx
	double ty
CODE:
	if(hpdist >= 0) {
		gluUnProject(hp.x,hp.y,hp.z,rh.modelMatrix,rh.projMatrix,viewport,
			&x,&y,&z);
		RETVAL = rh.node;
	} else {
		RETVAL=0;
	}
OUTPUT:
	RETVAL
	x
	y
	z
	nx
	ny
	nz
	tx
	ty

void
set_divs(horiz,vert)
int horiz
int vert
CODE:
	horiz_div = horiz;
	vert_div = vert;

ENDHERE
;
	print XS join '',@xsfn;
	print XS '

BOOT:
	I_OPENGL;

';

	open PM, ">VRMLFunc.pm";
	print PM "
# VRMLFunc.pm, generated by VRMLC.pm. DO NOT MODIFY, MODIFY VRMLC.pm INSTEAD
package VRML::VRMLFunc;
require DynaLoader;
\@ISA=DynaLoader;
bootstrap VRML::VRMLFunc;
sub load_data {
	my \$n = \\\%VRML::CNodes;
";
	print PM join '',@poffsfn;
	print PM "
}
";
}


gen();



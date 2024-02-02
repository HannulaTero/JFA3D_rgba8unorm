
/// @func	TiteJFA3D(width, height, depth);
/// @desc	Jump Flood Algorithm, generates coordinate mapping of closest seeds and distance field. 
/// @param	{Real}	_w
/// @param	{Real}	_h
/// @param	{Real}	_d
/// @Return	{Struct.TiteJFA}
function TiteJFA3D(_w=256, _h=256, _d=256) constructor 
{
//==========================================================
//
#region VARIABLE DECLARATION


	// Variables initialization.
	self.shape = [1, 1, 1];
	self.width = 1;
	self.height = 1;
	self.threshold = 0.5;
	self.jumpMax = infinity;
	self.surfaces = {
		temp:		-1,
		mapping:	-1,
		reverse:	-1,
		fill:		-1,
		field:		-1,
		lookup:		-1,
		vertex:		-1
	};
	self.enable = {
		fill:	true,
		field:	true,
		lookup:	true,
		vertex:	false
	};
	
	// Set to wanted shape.
	self.Reshape(_w, _h, _d);


#endregion
// 
//==========================================================
//
#region USER HANDLE METHODS
	
	
	// User handle: Reshape surfaces.
	static Reshape = function(_w=256, _h=256, _d=256) 
	{
		// Reshape dimensions.
		self.shape[0] = clamp(ceil(_w), 1, 256);
		self.shape[1] = clamp(ceil(_h), 1, 256);
		self.shape[2] = clamp(ceil(_d), 1, 256);
		
		// Get surface size.
		var _count	= self.shape[0] * self.shape[1] * self.shape[2];
		self.width	= ceil(sqrt(_count));
		self.height = ceil(sqrt(_count));
		
		// Give warning, if given dimensions were not valid.
		if (self.width != _w) || (self.height != _h) || (self.depth != _d)
		{
			var _warning = $"[TiteJFA3D] Warning: "
				_warning += $"Dimensions [{_w}, {_h}, {_d}] are not valid, ";
				_warning += $"dimensions {self.shape} used instead.";
			show_debug_message(_warning);
		}
		
		return self;	
	};
	
	
	// User handle: Set jump flood parameters.
	static Params = function(_theshold=0.5, _jumpMax=infinity) 
	{
		self.threshold = _theshold;
		self.jumpMax = _jumpMax;
		return self;
	};
	
	
	// User handle: Which actions are executed when updating.
	static Enable = function(_fill=true, _field=true, _lookup=true, _vertex=false) 
	{
		self.enable.fill = _fill;
		self.enable.field = _field;
		self.enable.lookup = _lookup;
		self.enable.vertex = _vertex;
		return self;
	};
	
	
	// User handle: Do jump flooding and update all surfaces by given seed.
	static Update = function(_seed) 
	{
		// Get the uniform handles.
		static __shader			= shdTiteJFA3D;
		static __uniAction		= shader_get_uniform(__shader, "uniAction");
		static __uniSize		= shader_get_uniform(__shader, "uniSize");
		static __uniTexel		= shader_get_uniform(__shader, "uniTexel");
		static __uniShape		= shader_get_uniform(__shader, "uniShape");
		static __uniThreshold	= shader_get_uniform(__shader, "uniThreshold");
		static __uniJumpMax		= shader_get_uniform(__shader, "uniJumpMax");
		static __texB			= shader_get_sampler_index(__shader, "texB");
		
		// Set up gpu state.
		var _previous = shader_current();
		gpu_push_state();
		gpu_set_tex_repeat(false);
		gpu_set_tex_filter(false);
		gpu_set_blendenable(false);
		shader_set(__shader);
		
		// Preparations.
		var _w = self.width;
		var _h = self.height;
		self.surfaces.temp = self.Verify(self.surfaces.temp);
		self.surfaces.mapping = self.Verify(self.surfaces.mapping);
		self.surfaces.reverse = self.Verify(self.surfaces.reverse);
		shader_set_uniform_f(__uniSize, _w, _h);
		shader_set_uniform_f(__uniTexel, 1.0/_w, 1.0/_h);
		shader_set_uniform_f_array(__uniShape, self.shape);
		
		// Get the regular seed coordinates.
		shader_set_uniform_i(__uniAction, 0);
		shader_set_uniform_f(__uniThreshold, self.threshold);
		surface_set_target(self.surfaces.mapping);
		draw_surface_stretched(_seed, 0, 0, _w, _h);
		surface_reset_target();
		
		// Get the reverse seed coordinates.
		shader_set_uniform_i(__uniAction, 1);
		surface_set_target(self.surfaces.reverse);
		draw_surface_stretched(self.surfaces.mapping, 0, 0, _w, _h);
		surface_reset_target();
		
		// Get Coordinate mappings by Jump Flood passes.
		shader_set_uniform_i(__uniAction, 2);
		shader_set_uniform_f(__uniJumpMax, self.jumpMax);
		var _jumpW = min(self.shape[0], self.jumpMax);
		var _jumpH = min(self.shape[1], self.jumpMax);
		var _jumpD = min(self.shape[2], self.jumpMax);
		self.__JumpFlood(self.surface.mapping, _jumpW, _jumpH, _jumpD);
		self.__JumpFlood(self.surface.reverse, _jumpW, _jumpH, _jumpD);
		
		// Optional: Generate surface which is filled.
		if (self.enable.fill) 
		{
			self.surfaces.fill = self.Verify(self.surfaces.fill);
			shader_set_uniform_i(__uniAction, 3);
			texture_set_stage(__texB, surface_get_texture(_seed));
			surface_set_target(self.surfaces.fill);
			draw_surface_stretched(self.surfaces.mapping, 0, 0, _w, _h);
			surface_reset_target();
		}
		
		// Optional: Generate normal & signed distance field.
		if (self.enable.field)
		{
			self.surfaces.field = self.Verify(self.surfaces.field);
			shader_set_uniform_i(__uniAction, 4);
			texture_set_stage(__texB, surface_get_texture(self.surface.reverse));
			surface_set_target(self.surfaces.field);
			draw_surface_stretched(self.surfaces.mapping, 0, 0, _w, _h);
			surface_reset_target();
		}
		
		// Optional: Generate lookup table.
		if (self.enable.lookup)
		{
			self.surfaces.lookup = self.Verify(self.surfaces.lookup);
			shader_set_uniform_i(__uniAction, 5);
			surface_set_target(self.surfaces.lookup);
			draw_surface_stretched(self.surfaces.mapping, 0, 0, _w, _h);
			surface_reset_target();
		}
		
		// Optional: Generate vertices.
		if (self.enable.vertex)
		{
			self.surfaces.vertex = self.Verify(self.surfaces.vertex);
			shader_set_uniform_i(__uniAction, 6);
			surface_set_target(self.surfaces.vertex);
			draw_surface_stretched(self.surfaces.mapping, 0, 0, _w, _h);
			surface_reset_target();
		}
		
		// Return previous gpu state.
		gpu_pop_state();
		if (_previous != -1) 
			shader_set(_previous);
		else 
			shader_reset();
		return self;
	};
	
	
	// User handle: Verify all surfaces exists and are in correct shape, recreate if not.
	static Verify = function(_surface) 
	{
		// Check whether in correct shape
		if (surface_exists(_surface))
		{
			// Force recreation if wrong.
			if (surface_get_width(_surface) != self.width)
			|| (surface_get_height(_surface) != self.height)
			|| (surface_get_format(_surface) != surface_rgba8unorm)
			{
				surface_free(_surface);
			}
		}
			
		// Recreate missing surface.
		if (!surface_exists(_surface))
		{
			_surface = surface_create(self.width, self.height);
		}
		return _surface;
	};
	
	
	// User handle: Free all surfaces.
	static Free = function() 
	{
		// Iterate through all surfaces.
		struct_foreach(self.surfaces, function(key, element) 
		{
			// Free the surface.
			if (surface_exists(element))
			{
				surface_free(element);
			}
		});
		return self;
	};



#endregion
// 
//==========================================================
//
#region HELPER METHODS


	// Separates each axis into own passes.
	// This way only 9 samples is required instead of 27.
	// This of course requires more passes, but in higher dimensions it is better.
	static __JumpFlood = function(_target, _jumpW, _jumpH, _jumpD) 
	{		
		// Preparations.
		var _tempA = self.surfaces.temp;
		var _tempB = _target;
		var _tempC = _target;
		
		// Iterate until necessary jumps have been done.
		while(max(_jumpW, _jumpH, _jumpD) > 1.0) 
		{
			_jumpW = floor(_jumpW * 0.5);
			_jumpH = floor(_jumpH * 0.5);
			_jumpD = floor(_jumpD * 0.5);
			if (_jumpW > 0.0) self.__JumpPass(_tempB, _tempA, _jumpW, 0, 0);
			if (_jumpH > 0.0) self.__JumpPass(_tempA, _tempB, 0, _jumpH, 0);
			if (_jumpD > 0.0) self.__JumpPass(_tempB, _tempA, 0, 0, _jumpD);
			_tempC = _tempB;
			_tempB = _tempA;
			_tempA = _tempC;
		}
		
		// Make sure last pass is saved into target.
		if (_target != _tempC) 
		{
			surface_copy(_target, 0, 0, _tempC);
		}
		return self;
	}
	
	
	// Does one third of single jump pass, along one dimensional axis.
	static __JumpPass = function(_dst, _src, _jumpW, _jumpH, _jumpD) 
	{
		static __uniJumpDist = shader_get_uniform(shdTiteJFA3D, "uniJumpDist");
		shader_set_uniform_f(__uniJumpDist, _jumpW, _jumpH, _jumpD);
		surface_set_target(_dst);
		draw_surface_stretched(_src, 0, 0, self.width, self.height);
		surface_reset_target();
		return self;
	}


#endregion
// 
//==========================================================
}












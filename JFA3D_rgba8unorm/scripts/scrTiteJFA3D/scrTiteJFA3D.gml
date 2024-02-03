
/// @func	TiteJFA3D(width, height, depth);
/// @desc	Jump Flood Algorithm, generates coordinate mapping of closest seeds and distance field. 
/// @param	{Real}	_w	Width	as power of 2.
/// @param	{Real}	_h	Height	as power of 2.
/// @param	{Real}	_d	Depth	as power of 2.
/// @Return	{Struct.TiteJFA}
function TiteJFA3D(_w=128, _h=128, _d=128) constructor 
{
//==========================================================
//
#region VARIABLE DECLARATION


	// Variables initialization.
	self.width = 1;
	self.height = 1;
	self.shape = [1, 1, 1];
	self.threshold = 0.5;
	self.jumpMax = infinity;
	self.surfaces = {
		temp:	 -1,
		mapping: -1,
		reverse: -1,
		fill:	 -1,
		field:	 -1
	};
	self.enable = {
		fill:	true,
		field:	true
	};
	
	// Set to wanted shape.
	self.Reshape(_w, _h, _d);


#endregion
// 
//==========================================================
//
#region USER HANDLE METHODS
	
	
	// User handle: Reshape surfaces.
	static Reshape = function(_w=128, _h=128, _d=128) 
	{
		// Set 3D dimensions, force powers of 2.
		self.shape[0] = clamp(power(2.0, ceil(log2(_w))), 1, 256);
		self.shape[1] = clamp(power(2.0, ceil(log2(_h))), 1, 256);
		self.shape[2] = clamp(power(2.0, ceil(log2(_d))), 1, 256);
		
		// Get surface size.
		self.width	= self.shape[0] * (self.shape[2] mod 16.0);
		self.height = self.shape[1] * (self.shape[2] div 16.0);
		
		// Give warning, if given dimensions were not valid.
		if (self.shape[0] != _w) || (self.shape[1] != _h) || (self.shape[2] != _d)
		{
			var _warning = $"[TiteJFA3D_Surface] Warning: "
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
	static Enable = function(_fill=true, _field=true) 
	{
		self.enable.fill = _fill;
		self.enable.field = _field;
		return self;
	};
	
	
	// User handle: Do jump flooding and update surfaces by given seed.
	static Update = function(_seed) 
	{
		// Get the uniform handles.
		static __shader			= shdTiteJFA3D;
		static __uniAction		= shader_get_uniform(__shader, "uniAction");
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
			texture_set_stage(__texB, self.surface.reverse.Texture());
			surface_set_target(self.surfaces.field);
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
	

	// User handle: Verify surface exists and are in correct shape, recreate if not.
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
	
	
	// User handle: Free all dasurfacesta.
	static Free = function() 
	{
		struct_foreach(self.surfaces, function(_key, _element) 
		{
			if (surface_exists(_element))
			{
				surface_free(_element);
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
		static __uniJumpA = shader_get_uniform(shdTiteJFA3D, "uniJumpA");
		static __uniJumpB = shader_get_uniform(shdTiteJFA3D, "uniJumpB");
		shader_set_uniform_f(__uniJumpA, +_jumpW, +_jumpH, +_jumpD);
		shader_set_uniform_f(__uniJumpB, -_jumpW, -_jumpH, -_jumpD);
		surface_set_target(_dst);
		draw_surface_stretched(_src, 0, 0, self.width, self.height);
		surface_reset_target();
		return self;
	}
	

#endregion
// 
//==========================================================
}












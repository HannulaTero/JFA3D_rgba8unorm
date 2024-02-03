

/// @func	TiteJFA3D_Data(width, height, depth);
/// @desc	
/// @param	{Real}	_w	Width	as power of 2.
/// @param	{Real}	_h	Height	as power of 2.
/// @param	{Real}	_d	Depth	as power of 2.
function TiteJFA3D_Surface(_w=1, _h=1, _d=1) constructor
{
//==========================================================
//
#region VARIABLE DECLARATION


	// Variables initialization.
	self.width = 1;					// Actual surface dimensions.
	self.height = 1;				// 
	self.shape = [1, 1, 1];			// 3D shape that surface represents.
	self.surface = -1;				// Surface data.
	
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
		
		// Give warning, if given dimensions were not valid.
		if (self.shape[0] != _w) || (self.shape[1] != _h) || (self.shape[2] != _d)
		{
			var _warning = $"[TiteJFA3D_Surface] Warning: "
				_warning += $"Dimensions [{_w}, {_h}, {_d}] are not valid, ";
				_warning += $"dimensions {self.shape} used instead.";
			show_debug_message(_warning);
		}
		
		// Get stride for lookup linearization.
		self.stride[0] = 1.0;
		self.stride[1] = self.stride[0] * self.shape[0];
		self.stride[2] = self.stride[1] * self.shape[1];
		self.stride[3] = self.stride[2] * 16.0;
		
		// Get surface size.
		self.width	= self.shape[0] * (self.shape[2] mod 16.0);
		self.height = self.shape[1] * (self.shape[2] div 16.0);
		return self;	
	};
	
	
	// User handle: Get surface index.
	static Surface = function() 
	{
		// Check whether in correct shape
		if (surface_exists(self.surface))
		{
			// Force recreation if wrong.
			if (surface_get_width(self.surface) != self.width)
			|| (surface_get_height(self.surface) != self.height)
			|| (surface_get_format(self.surface) != surface_rgba8unorm)
			{
				surface_free(self.surface);
			}
		}
			
		// Recreate missing surface.
		if (!surface_exists(self.surface))
		{
			self.surface = surface_create(self.width, self.height);
		}
		return self.surface;
	};
	
	
	// User handle: Get texture pointer.
	static Texture = function()
	{
		return surface_get_texture(self.Surface());	
	};
	
	
	// User handle: Store into the buffer.
	static ToBuffer = function(_buffer) 
	{
		buffer_get_surface(_buffer, self.surface, 0);
		return buff;
	}
	
	
	// User handle: Get data from the buffer.
	static FromBuffer = function(_buffer) 
	{
		buffer_set_surface(_buffer, self.fsurface, 0);
		return self;
	}
	
	
	// User handle: Get byte count for buffer.
	static Bytecount = function() 
	{
		return 4 * self.width * self.height;
	}
	
	
	// User handle: Copies of datastructure from another.
	//  - Doesn't copy the contents
	static Copy = function(_data)
	{
		self.width = _data.width;
		self.height = _data.height;
		self.shape = variable_clone(_data.shape);
		self.stride = variable_clone(_data.stride);
		return self;
	}
	
	
	// User handle: Makes a new clone, copies content.
	static Clone = function() 
	{
		// feather ignore GM2023
		var _clone = new TiteJFA3D_Surface();
			_clone.Copy(self);
		surface_copy(_clone.Surface(), 0, 0, self.Surface());
		return _clone;
	}
	
	
	// User handle: Free surface.
	static Free = function() 
	{
		if (surface_exists(self.surface))
		{
			surface_free(self.surface);
		}
		return self;
	};
	

#endregion
// 
//==========================================================
}
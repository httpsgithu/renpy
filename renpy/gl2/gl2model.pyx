# Copyright 2004-2025 Tom Rothamel <pytom@bishoujo.us>
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation files
# (the "Software"), to deal in the Software without restriction,
# including without limitation the rights to use, copy, modify, merge,
# publish, distribute, sublicense, and/or sell copies of the Software,
# and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

from renpy.display.render import IDENTITY
from renpy.display.matrix import Matrix
from renpy.gl2.gl2polygon cimport Polygon
from renpy.gl2.gl2texture cimport GLTexture

from libc.math cimport ceil

cdef class GL2Model:
    """
    A model can be placed as a leaf of the tree of Renders, and contains
    everything needed to be draw to the screen.
    """

    def __init__(GL2Model self, size, mesh, shaders, uniforms, properties=None):
        self.width = size[0]
        self.height = size[1]
        self.mesh = mesh
        self.shaders = shaders
        self.uniforms = uniforms
        self.properties = properties
        self.cached_texture = None

        self.forward = IDENTITY
        self.reverse = IDENTITY

    def __repr__(GL2Model self):
        rv = "<{} {}x{} {} {}".format(type(self).__name__, self.width, self.height, self.shaders, self.uniforms)

        if self.forward is not IDENTITY:
            rv += "\n    forward (to mesh):\n    " + repr(self.forward).replace("\n", "\n    ")
            rv += "\n    reverse (to screen):\n    " + repr(self.reverse).replace("\n", "\n    ")

        rv += "\n    " + repr(self.mesh).replace("\n", "\n    ")
        rv += ">"

        return rv

    def load(self):
        """
        Loads the textures associated with this model.
        """

        for i in self.uniforms.itervalues():
            if isinstance(i, GLTexture):
                i.load()

    def get_uniforms(self):
        return self.uniforms

    def get_size(self):
        """
        Returns the size of this GL2Model.
        """

        return (self.width, self.height)

    cpdef GL2Model copy(GL2Model self):
        """
        Creates an identical copy of the current model.
        """

        cdef GL2Model rv = GL2Model((self.width, self.height), self.mesh, self.shaders, self.uniforms, self.properties)
        rv.forward = self.forward
        rv.reverse = self.reverse

        return rv

    cpdef subsurface(GL2Model self, rect):
        """
        Given a rectangle `rect`, returns a GL2Model that only contains the
        portion of the model inside the rectangle.
        """

        cdef float x, y, w, h

        x, y, w, h = rect

        cdef GL2Model rv = self.copy()

        rv.width = <int> ceil(w)
        rv.height = <int> ceil(h)

        rv.reverse = rv.reverse * Matrix.coffset(-x, -y, 0)
        rv.forward = Matrix.coffset(x, y, 0) * rv.forward

        cdef Polygon p = Polygon.rectangle(0, 0, w, h)
        p.multiply_matrix_inplace(rv.forward)

        rv.mesh = rv.mesh.crop(p)

        return rv

    cpdef scale(GL2Model self, float factor):
        """
        Creates a new model that is this model scaled by a constant factor.
        """

        cdef float reciprocal_factor

        cdef GL2Model rv = self.copy()

        rv.width = <int> ceil(rv.width * factor)
        rv.height = <int> ceil(rv.height * factor)

        rv.reverse = rv.reverse * Matrix.scale(factor, factor, factor)

        if factor <= 0.0:
            # Map everything onto the (0, 0, 0) point for the zero-
            # scale case.
            rv.forward =  Matrix.cscale(0, 0, 0) * rv.forward
        else:
            reciprocal_factor = 1.0 / factor
            rv.forward = Matrix.cscale(reciprocal_factor, reciprocal_factor, reciprocal_factor) * rv.forward

        return rv

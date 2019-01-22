# Pagedraw Layout System 1.0 Spec

### 1) Primitives

1.1) Flexible length: I'll grow with my parent proportionally to how big I am. 1.2) In the flexible case, my min-length is the length of my non-flexible content

1.3) The opposite of Flex length is **not** Fixed length. Layout System 1.0 does not have a fixed length primitive. The opposite of Flex length is content . That means a block's size will be determined by its content.

1.4) In a case like a simple rectangle with no children inside (or a non flexible margin), its content is just a fixed geometry. In that case we get behavior analogous to "fixed".

### 2) Constraint resolution

Parent wins against children.

2.1) If a parent says it's flexible, we'll force some child to be flexible even if none of the children say they're flexible.

2.2) If a parent says it's content, we'll force all children to be content as well.

2.3) When margins disagree, flexible wins against content.

### 3) Components and Layout

A component can specify any of its lengths to be "resizable." If a length is resizable, we can resize it in the instances.

3.1) If a component's length is resizable and the instance length is not flexible, the size of the instance determines a min-length along that axis.

3.2) Instances can be made flexible on some axis if and only if a component's length is resizable along that axis.

3.3) Resizable instances marked flexible work just like in the regular flexible case, with the exception of the extra min-length mentioned in 3.1.

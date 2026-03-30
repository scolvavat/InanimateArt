# Inanimate Art

**Swift Student Challenge 2026 submission**

## overview

For the 2026 Swift Student Challenge, I wanted to explore how technology could make art feel more accessible across different cultural contexts. I focused on the role of art in Islam, where depictions of living things are often discouraged, and where mosaic-style art has historically been a more appropriate visual form.

That led me to the core challenge behind **Inanimate Art**:

**Can I take any image and transform it into mosaic-style artwork without destroying what made the original image meaningful?**

Instead of solving that with a simple filter, blur, or crossfade, I wanted to build something that kept the original image intact at the pixel level. That meant no deleting pixels, no inventing new ones, and no taking shortcuts with blending tricks. The result was an app that repositions the original pixels into a new structure, creating something that feels more inanimate while still preserving the source image.

---

## challenge-based learning journey

This project was built through experimentation, iteration, and problem-solving.

At the start, I knew the cultural problem I wanted to respond to, but I did not yet know the right technical approach. My first question was not just *how do I stylize an image?* but:

- how do I transform an image without replacing it?
- how do I keep every original pixel?
- how do I make the result feel like a true transformation instead of a filter?

That led me to think of the image not as a flat picture, but as a collection of individual pieces that could be moved and reorganized. From there, the project became a challenge in simulation, rendering, and motion.

I explored how to:
- break an image into units that could move
- match those units to a new visual structure
- preserve the original color information
- render the result in a way that still looked coherent and intentional

That process pushed me into working with GPU rendering, image simulation, and custom Metal logic to make the effect work in real time.

---

## what this app is

**Inanimate Art** is an iOS app that transforms an image into mosaic-style artwork by rearranging its original pixels instead of filtering or replacing them.

Instead of crossfading or applying a preset effect, the app breaks an image into a grid of moving “seeds” and remaps them across the image.

So:
- parts of the image actually **move**
- the original color data is still preserved
- the end result feels more like a **warp / morph** than a filter

This was important to me because I wanted the transformation to feel earned through motion and structure, not generated artificially.

---

## how it works

The process goes roughly like this:

- take a source image and a target image
- resize both to a fixed simulation grid (for example 64x64)
- create one seed per pixel
- match source seeds to target positions mostly by brightness
- move seeds over time using damped motion
- use Metal to rebuild the final image every frame

This creates an animated transformation where the image reorganizes itself while still being built out of its original visual material.

---

## the core idea

> seeds move, color doesn’t

This became the most important design rule in the project.

Each seed stores:
- a **current position**, which moves during the simulation
- an **original position**, which is still used for color sampling

That means the image can shift, stretch, and reorganize, but the color is always tied back to where it originally came from. This is what helps the final result stay visually connected to the original image instead of turning into random noise.

---

## rendering approach

To make the effect feel smooth and believable, I used a Metal compute shader to render the image per pixel.

For each output pixel, the shader:
- finds the nearest seed in a Voronoi-style way
- keeps track of the local offset inside that region
- samples the original image at an adjusted position

This was a major part of the learning process, because I was not just applying an image effect — I was rebuilding the final image from a moving simulation.

That is also why the result feels more like a warp than a simple filter.

---

## simulation approach

The simulation handles how the seeds move and where they are assigned.

To make the motion more visually coherent, I used:
- **brightness bins**, so darker areas tend to map to darker areas and lighter areas to lighter ones
- **Morton order**, so nearby pixels stay relatively nearby in memory and space
- **spring + damping motion**, so the transition feels smoother and more natural over time

I also track average seed speed so the system can detect when the movement has mostly settled.

This part of the project taught me a lot about balancing visual logic with performance. I had to think not just about where pixels should go, but how they should move in a way that still looked intentional.

---

## double pass

One of the more interesting ideas I experimented with was a double-pass transformation.

The process is:
- run the morph once
- take that output
- feed it back in
- run the morph again

This makes the effect stronger without changing the core system. It was a useful way to push the mosaic-like result further while still staying consistent with the project’s main rule of preserving and reusing the original image data.

---

## performance decisions

Because this project was built for real-time interaction, performance mattered a lot.

To keep the app responsive:
- the simulation runs at a lower resolution
- the output still renders at full size
- heavy rendering work is pushed onto the GPU using Metal
- brute-force nearest-seed search is acceptable because the simulation grid stays relatively small

A big part of the challenge was learning where I could simplify and where I needed more precision. That balance shaped a lot of the final system.

---

## tech used

- Swift
- SwiftUI
- Metal / MetalKit
- UIKit
- PhotosUI
- Photos
- CoreGraphics

These tools each supported different parts of the experience, from image selection and app structure to simulation and GPU rendering.

---

## why I made it

This project was inspired in part by image transformation tools like **Obamify**, but I wanted to build something that felt more intentional, technically challenging, and culturally grounded.

My goals were:
- real-time rendering
- full control over the visual pipeline
- no shortcuts through blending or standard image filters
- a result that felt meaningfully transformed, not just edited

More than anything, I wanted the app to show how a technical system could respond to a cultural idea in a respectful and creative way.

---

## what I learned

Through building **Inanimate Art**, I learned more about:
- using challenge-based learning to move from a cultural question into a technical system
- translating an abstract idea into concrete simulation rules
- working with GPU rendering in Metal
- balancing visual quality with performance
- building a project where technical constraints were part of the concept, not just part of the implementation

This project pushed me to think like both a designer and a developer.

---

## what I would improve next

If I kept developing the project, I would want to:
- replace brute-force nearest-seed lookup with a spatial data structure
- support higher simulation resolutions without hurting performance
- add more controls for different mosaic styles and transformation intensity

---

## context

Built solo for the **Swift Student Challenge 2026**

Main areas of focus:
- GPU rendering
- simulation and animation
- image transformation
- challenge-based learning
- building something that feels different from a typical image effect

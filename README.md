# Inanimate Art

**Swift Student Challenge 2026 submission**

For the 2026 SSC I wanted to make art more accessible to muslims. In cultures like Islam art containing living things is not permitted so the goal of this app is to turn any given image into a mosaic art to be more appropriate for the culture while keeping the original photo intact (no deleting pixels or creating new ones)
---

## what this is

instead of crossfading or applying filters, this breaks an image into a grid of moving “seeds” and re-maps them to match a target image

so:
- things actually **move across the image**
- but color still comes from the original layout

end result is more of a **warp/morph** than a filter

---

## how it works

- take source + target image  
- resize both to a fixed sim grid (ex: 64x64)  
- create one seed per pixel  
- match source → target mostly by brightness  
- move seeds over time using damped motion  
- use Metal to rebuild the final image every frame  

---

## the important idea

> seeds move, color doesn’t

each seed has:
- current position (moves)
- original position (used for sampling)

so even though everything shifts around, the image still looks coherent

---

## rendering 

- runs a Metal compute shader per pixel  
- finds nearest seed (Voronoi-style)  
- keeps local offset inside that region  
- samples original image at adjusted position  

this is why it looks like a warp instead of noise

---

## simulation 

- handles seed movement + matching  
- uses brightness bins (dark → dark, light → light)  
- uses Morton order so nearby pixels stay nearby  
- applies spring + damping so motion feels smooth  

also tracks average speed to detect when things “settle”

---

## double pass

- run the morph once  
- take the output  
- feed it back in  
- run it again  

makes the effect stronger without changing the core logic

---

## performance stuff

- sim runs at lower resolution  
- output still renders full size  
- heavy work done on GPU (Metal)  
- brute force nearest-seed works because sim size is small  

---

## tech used

- Swift  
- SwiftUI  
- Metal / MetalKit  
- UIKit (camera + photos)  
- CoreGraphics  

---

## why i made it

inspired by stuff like obamify but wanted:
- real-time rendering  
- full control over the pipeline  
- no shortcuts (no blending tricks)

---

## what i’d improve

- replace brute-force nearest seed with spatial structure  
- higher sim resolution without tanking performance  
- more controls for different styles  

---

## context

built solo for the **Swift Student Challenge 2026**

focus was:
- gpu rendering  
- simulation + animation  
- making something that actually feels different from typical image effects  

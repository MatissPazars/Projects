


# Sheep Simulator. 
## The original Idea: Simulate Evolution.
The idea was that evolution fundementally requires just 4 things: variation between siblings (mutation), inheritance, conflict over shared / limited resources, time. the moment all 4 are true, evolution is not just *possible*, its MANDATORY. 
Thus, evolution is an emergent thing, not an thing of itself. 

### For the full code and logic of how the simulation works, please visit the S-3 folder above. 
### The Code was re-written by Google Antigravity for clarity as well as performance and documentation, as well as for efficiency. Gemini did NOT come up with the idea or concept. I am able to maintain the code without AI. 
Evolution was never in entirety introduced into the project (you are free to do it yourself if you wish to finish it), but the simple reason being that the simulation already reached its goal. The idea was to reach emergent behavior, but I over-estimated how simple the rules need to be for emergent behavior (ironic given I had already been very much aware of Conway's game of life) and thus the mutation part was never implemented for the specific reason that the simulation was already interesting even without it. 

<img width="865" height="755" alt="Screenshot 2026-08-03 195922(1)" src="https://github.com/user-attachments/assets/e3387f9a-e498-4429-a820-077210b45a3b" />
(the image is from an earlier version of the sheep simulator, thus the bottom display is NOT how it currently works)

interestingly the sheep simulator displays 3 emergent behavior-like patterns instantly noticeable: 
1. the nominal amount of sheep on the map follows an [S-Curve](https://en.wikipedia.org/wiki/Sigmoid_function). The pattern may not be always visible and it may change to what extend it is visible. NOTE:
   due to the 2nd pattern, it could technically also (with high merit) be argued that it in-fact actually forms an cumulative normal distribution graph instead of an S-curve. 
3. The net change of grass amount (i.e. - the amount of grass growing/spreading minus the amount of grass eaten by sheep) follows an normal distribution-like curve IF there are no sheep / if the sheep aren't able to sufficiently impact data and grass is left to simply spread itself, populating the field. 
4. Due to grass having distinct phases of growth and spreading, grass seems to form visible [Voronoi Diagram](https://en.wikipedia.org/wiki/Voronoi_diagram) patterns. because of the definition of an Voronoi Diagram, interestingly it isn't just a Voronoi-like but instead a pure Voronoi diagram. 



https://github.com/user-attachments/assets/3d824e42-288d-4b7f-b968-f804a3e78294

<img width="1600" height="1201" alt="image" src="https://github.com/user-attachments/assets/6e50d006-fc0e-4912-a5e6-ed5a6e3df77a" />
<img width="1600" height="1201" alt="image" src="https://github.com/user-attachments/assets/56178245-726f-4275-9367-11fb97d3c92b" />
My very first *major* project with my ESP32. an 3DOF Robotic arm.
I used my Elegoo Centauri Carbon 3D printer (with Elegoo Rapid PLA+ as the filament), an Freenove ESP32 Wrover Cam (without an camera, the camera broke), 3 Muizei 20kg*cm 180 degree digital servos, an Elegoo battery (from the Elegoo Smart Car V2.0 kit), 3 (one for each motor) LM2598 step-down converters, and potenciometers were used for controlling the motors. 
3D models made by Me in Autodesk Fusion (Riga Technical University thankfully gives a license). 
Slicing Software used: Elegoo Slicer.

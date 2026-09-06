



<img width="865" height="755" alt="Screenshot 2026-08-03 195922(1)" src="https://github.com/user-attachments/assets/e3387f9a-e498-4429-a820-077210b45a3b" />
(the image is from an earlier version of the sheep simulator, thus the bottom display is NOT how it currently works)

interestingly the sheep simulator displays 3 emergent behavior-like patterns instantly noticeable: 
1. the nominal amount of sheep on the map follows an [S-Curve](https://en.wikipedia.org/wiki/Sigmoid_function). The pattern may not be always visible and it may change to what extend it is visible. NOTE:
   due to the 2nd pattern, it could technically also (with high merit) be argued that it in-fact actually forms an cumulative normal distribution graph instead of an S-curve. 
3. The net change of grass amount (i.e. - the amount of grass growing/spreading minus the amount of grass eaten by sheep) follows an normal distribution-like curve IF there are no sheep / if the sheep aren't able to sufficiently impact data and grass is left to simply spread itself, populating the field. 
4. Due to grass having distinct phases of growth and spreading, grass seems to form visible [Voronoi Diagram](https://en.wikipedia.org/wiki/Voronoi_diagram) patterns. because of the definition of an Voronoi Diagram, interestingly it isn't just a Voronoi-like but instead a pure Voronoi diagram. 

using CSV, DataFrames
using WGLMakie, JSServe
using Colors, ColorSchemes
using FileIO, Downloads
using GeometryBasics

function sphere(; r = 1.0, n=32)
    theta = LinRange(0, pi, n)
    phi = LinRange(-pi, pi, 2*n)
    x = [r * cos(phi) * sin(theta) for theta in theta, phi in phi]
    y = [r * sin(phi) * sin(theta) for theta in theta, phi in phi]
    z = [r * cos(theta) for theta in theta, phi in phi]
    return (x, y, z)
end 

# Function to convert lat lon to the x,y,z coordinate
function toCartesian(lon , lat ; r = 1.02, cxyz = (0,0,0))
    x = cxyz[1] + (r + 1500_000)*cosd(lat)*cosd(lon)
    y = cxyz[2] + (r + 1500_000)*cosd(lat)*sind(lon)
    z = cxyz[3] + (r + 1500_000)*sind(lat)

    return (x, y, z) ./ 1500_000

end

# Read the site data 
# Compiled from two different files: Checked on 11/02/2022
# Location file https://fluxnet.org/sites/site-list-and-pages/
# TimePeriod Available https://fluxnet.org/data/data-availability/

site_data = DataFrame(CSV.File("input_folder/site_data.csv"))

# Manually downloaded the image
# https://visibleearth.nasa.gov/collection/1484/blue-marble
earth_img = load("input_folder/eo_base_2020_clean_3600x1800_small.png")

mag =  site_data.END_YEAR - site_data.STRT_YEAR 
lon , lat = site_data.LOCATION_LONG, site_data.LOCATION_LAT

app = App() do session::Session
	slider = JSServe.Slider(1:1:18)

	fig =  Figure(resolution = (1000,1000), fontsize = 24)
	ax = LScene(fig[1,1], show_axis = false)

	surface!(ax, sphere(; r = 1.0)..., 
		color = earth_img,
		shading = false, 
		transparency = false         
		)

	# Label(fig[1, 1, Bottom()], "Visualization by @mohitanand")

	toPoints3D = [Point3f([toCartesian(lon[i], lat[i]; r = 0)...]) for i in eachindex(lon)];

	index = mag.>1

	Points3D = Observable(toPoints3D[index])
	Mag = Observable(mag[index])
	dotsize = Observable(Mag.val/1000)

	pltobj = meshscatter!(ax, Points3D,
	  markersize = dotsize,
	  color = Mag#,
	  #shading = true, 
	  #ambient = Vec3f(1.0,1.0,1.0)
	  )

	# Colorbar(fig[1,2], limits = (0, 22), label="Number of Years", height = Relative(1/2))

	event = on(slider) do sval
	  index = mag.>sval
	  Points3D.val = toPoints3D[index]
	  Mag.val = mag[index]
	  dotsize.val = Mag.val/1000

	  Points3D[] = Points3D.val
          Mag[] = Mag.val
	  dotsize[] = dotsize.val	  	  
  	end
	
        sl = DOM.div("NumYear: ", slider, slider.value)	
        return JSServe.record_states(session, DOM.div(sl, fig))
end


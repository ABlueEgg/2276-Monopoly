extends Node2D

const CARDS = { 

	#first value is attack and second value is health
	#we can modify it with color and value later
	"DB_ParkPlace": [2,"dblue"],
	"DB_BroadWalk": [1,"dblue"],
	"R_KentuckyAve": [1,"red"],
	"R_Illinois": [5,"red"],
	"R_IndianaAve":[1,"red"],
	"G_NorthCarolinaAve":[1,"green"],
	"G_PacificAve":[2,"green"],
	"G_PennsylvaniaAve":[2,"green"],
	"Y_AtlanticAve":[4,"yellow"],
	"Y_MarvinGardens":[1,"yellow"],
	"Y_VentnorAve":[3,"yellow"]
	
}

var COLOURS = { 
	#indicates how many properties each colour needs 
	#to be a full set
	"red": 3,
	"dblue": 2,
	"green": 3,
	"yellow": 3
	
}

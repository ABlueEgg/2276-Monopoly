extends Node2D

const CARDS = { 

	#first value is attack and second value is health
	#we can modify it with color and value later
	"DB_ParkPlace": [4,"dblue"],
	"DB_BroadWalk": [4,"dblue"],
	"R_KentuckyAve": [3,"red"],
	"R_Illinois": [3,"red"],
	"R_IndianaAve":[3,"red"],
	"G_NorthCarolinaAve":[4,"green"],
	"G_PacificAve":[4,"green"],
	"G_PennsylvaniaAve":[4,"green"],
	"Y_AtlanticAve":[3,"yellow"],
	"Y_MarvinGardens":[3,"yellow"],
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

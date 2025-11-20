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
	"Y_VentnorAve":[3,"yellow"],
	"U_WaterWorks":[2,"utility"],
	"U_ElectricCompany":[2,"utility"],
	"RR_BNO":[2,"Railroad"],
	"RR_Penns":[2,"Railroad"],
	"RR_ShortLine":[2,"Railroad"],
	"RR_Reading":[2,"Railroad"],
	"LB_ConnectAve":[1, "lightblue"],
	"LB_OrientalAve":[1, "lightblue"],
	"LB_VermontAve":[1, "lightblue"],
	"P_StatesAve":[2,"pink"],
	"P_StCharlesPlace":[2,"pink"],
	"P_VirginiaAve":[2,"pink"],
	"O_NewYorkAve":[2,"orange"],
	"O_StJamesPlace":[2,"orange"],
	"O_TennAve":[2,"orange"],
	"B_BalticAve":[1,"brown"],
	"B_MediAve":[1,"brown"]
	
}

var COLOURS = { 
	#indicates how many properties each colour needs 
	#to be a full set
	"red": 3,
	"dblue": 2,
	"green": 3,
	"yellow": 3,
	"utility":2,
	"Railroad":4,
	"lightblue":3,
	"pink":3,
	"orange":3,
	"brown": 2
	
}

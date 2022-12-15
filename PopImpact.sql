--
-- PostgreSQL database dump
--

-- Dumped from database version 14.0
-- Dumped by pg_dump version 14.0

-- Started on 2022-12-15 08:27:11

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

DROP DATABASE "POPIMPACT";
--
-- TOC entry 4335 (class 1262 OID 2757136)
-- Name: POPIMPACT; Type: DATABASE; Schema: -; Owner: postgres
--

CREATE DATABASE "POPIMPACT" WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE = 'Spanish_Spain.1252';


ALTER DATABASE "POPIMPACT" OWNER TO postgres;

\connect "POPIMPACT"

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 8 (class 2615 OID 2757140)
-- Name: OriginData; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA "OriginData";


ALTER SCHEMA "OriginData" OWNER TO postgres;

--
-- TOC entry 4336 (class 0 OID 0)
-- Dependencies: 8
-- Name: SCHEMA "OriginData"; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA "OriginData" IS 'schema to store the input data. The building and population layers that will be the input for buildings with output population.';


--
-- TOC entry 9 (class 2615 OID 2757138)
-- Name: Process; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA "Process";


ALTER SCHEMA "Process" OWNER TO postgres;

--
-- TOC entry 4337 (class 0 OID 0)
-- Dependencies: 9
-- Name: SCHEMA "Process"; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA "Process" IS 'scheme to save the functions that allow to harmonize and obtain the POPIMPACT´s buildings ';


--
-- TOC entry 5 (class 2615 OID 2757139)
-- Name: Result; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA "Result";


ALTER SCHEMA "Result" OWNER TO postgres;

--
-- TOC entry 4338 (class 0 OID 0)
-- Dependencies: 5
-- Name: SCHEMA "Result"; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA "Result" IS 'scheme to save the layers of generated buildings, the harmonized buildings are created first and then given the value of the population according to the chosen method or methods. The table with the results of the processes is also saved';


--
-- TOC entry 2 (class 3079 OID 2757144)
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- TOC entry 4339 (class 0 OID 0)
-- Dependencies: 2
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry and geography spatial types and functions';


--
-- TOC entry 952 (class 1255 OID 2758158)
-- Name: _DisaggregatePopulationBuildings(json); Type: FUNCTION; Schema: Process; Owner: postgres
--

CREATE FUNCTION "Process"."_DisaggregatePopulationBuildings"(json) RETURNS void
    LANGUAGE plpgsql
    AS $_$
  
 
	DECLARE
	-- PARSER JSON
		json_in json;
		uuid text;
		uuid2 text;
		EPSGProyect integer;
		
		--BUILDING
		SchemaBuilding  text;
		TableBuilding  text;
		GeometryBuildingName  text;
		EPSGBuilding integer;
		IdBuilding text;	
		GeometryBuilding text;		
		GeometryBuildingPU text;
				
		
		--POPULATION				
		SchemaPopulation  text;
		TablePopulation  text;
		GeometryPopulationName  text;		
		EPSGPopulation integer;
		IdPopulation text;	
		PopulationData text;	
		GeometryPopulation text;		

		Population double precision;
		CurrentGeometryPopulation geometry;
		CurrentIdPopulation  text;
		
		
		
	--variables		
	  	use_value text;
		UseFilter boolean;		
				

	  	MetodFootprint boolean;
		MetodVolumen boolean;
		MetodDWellings boolean;
		MetodResidencialArea boolean;
		
		TotalArea numeric;
		TotalVolumen numeric;
		TotalDWellings numeric;
		TotalResidencialArea numeric; 		
		BuildingArea numeric;		
		BuildingVolumen numeric;
		BuildingDwellings numeric;
		BuildingResidencialArea numeric;
		
		PopFootprint numeric;
		PopVolumen numeric;
		PopDwellings  numeric;
		PopResidencialArea  numeric;
		
		n_count integer;
		CurrentPopFootprint numeric;
		CurrentPopVolumen numeric;	
		CurrentPopDwellings numeric;	
		CurrentPopResidencialArea numeric;	
		
	--cursors and queries
		cursor_pob refcursor;
		record_pob record;
		record_sum_buil record;
		sql_query text;
		sql_query_without_filter text;
		sql_query_with_filter text;
		sql_base text;
		cursor_building refcursor;
		record_building record;
		
		--METADATA
		metadate_json json;
		ProcessTime time;
		Ambit text;
		NBuilding  integer;
		NPopArea integer;	
		
		--QUALITY		
		Footprint_NBuildingWithPop integer;
		Footprint_NBuildingWithoutPop integer;		
		Footprint_NBuildingMore100Pop integer;
 		Volumen_NBuildingWithPop integer;
		Volumen_NBuildingWithoutPop integer;		
		Volumen_NBuildingMore100Pop integer;
 		Dwellings_NBuildingWithPop integer;
		Dwellings_NBuildingWithoutPop integer;		
		Dwellings_NBuildingMore100Pop integer;
 		ResidencialArea_NBuildingWithPop integer;
		ResidencialArea_NBuildingWithoutPop integer;		
		ResidencialArea_NBuildingMore100Pop integer;
		
 		TotalPopulation integer;
		NZonaPopWithoutPop integer;
		FootprintPopFinal integer;
		VolumenPopFinal integer;
		DwellingsPopFinal integer;
		ResidencialAreaPopFinal integer;
		NBuildingWithoutFilter integer;
		NBuildingFilter integer;
		sql_query_metadata  text;
		
	BEGIN
	
	--TIME 
	  ProcessTime:= CURRENT_TIME;
 
	--PARSER DATA
		json_in:=$1::json;
		SchemaBuilding:=(json_in->'BuildingData'->>'SchemaName')::text;
		TableBuilding:=(json_in->'BuildingData'->>'TableName')::text;
		SchemaPopulation:=(json_in->'PopulationData'->>'SchemaName')::text;
		TablePopulation:=(json_in->'PopulationData'->>'TableName')::text;	
		GeometryBuildingName:=(json_in->'BuildingData'->>'geometry')::text;
		GeometryPopulationName:=(json_in->'PopulationData'->>'geometry')::text;
		EPSGBuilding:=(json_in->'BuildingData'->>'epsg')::integer;
		EPSGPopulation:=(json_in->'PopulationData'->>'epsg')::integer;	
		EPSGProyect:=(json_in->'Process'->>'epsg')::integer; 
		IdBuilding:=(json_in->'BuildingData'->>'IdData')::text;
		IdPopulation:=(json_in->'PopulationData'->>'Id')::text;
		PopulationData:=(json_in->'PopulationData'->>'PopulationField')::text;		
	  	use_value:=(json_in->'BuildingData'->>'useValue')::text;
	  	MetodFootprint:=(json_in->'Process'->>'MetodFootprint')::boolean;
		MetodVolumen:=(json_in->'Process'->>'MetodVolumen')::boolean;
		MetodDWellings:=(json_in->'Process'->>'MetodDWellings')::boolean;
		MetodResidencialArea:=(json_in->'Process'->>'MetodResidencialArea')::boolean;
	  	UseFilter:=(json_in->'Process'->>'UseFilter')::boolean;
		uuid:= (json_in->'Process'->>'IdProcess')::text;
		uuid2:=replace(uuid::text, '-', '_')::text;
		uuid2:=replace(uuid2::text, '-', '_')::text;
		uuid2:=replace(uuid2::text, '-', '_')::text;
		uuid2:=replace(uuid2::text, '-', '_')::text;
		uuid2:=replace(uuid2::text, '-', '_')::text;

	--CHECK EPSG LAYERS
	    If EPSGPopulation!= EPSGProyect then
	    	GeometryPopulation:='st_transform(pob."'||GeometryPopulationName||'", '||EPSGProyect||')';
	    ELSE 
	    	 GeometryPopulation:='pob."'||GeometryPopulationName||'"';
	    END IF; 
		If EPSGBuilding!= EPSGProyect then
	   	  GeometryBuilding:='st_transform(edif."'||GeometryBuildingName||'", '||EPSGProyect||')';	
		  GeometryBuildingPU:='st_transform(ST_PointOnSurface(edif."'||GeometryBuildingName||'"), '||EPSGProyect||')';	
	    ELSE 
	      GeometryBuilding:='edif."'||GeometryBuildingName||'"';
		  GeometryBuildingPU:='ST_PointOnSurface(edif."'||GeometryBuildingName||'")';		    
	    END IF;
		
			--SCOPE
		  sql_query:= 'SELECT ST_EstimatedExtent('''||SchemaBuilding||''','''||TableBuilding||''', '''||GeometryBuildingName||''');';
		  EXECUTE sql_query INTO Ambit; 
		  sql_query:= 'SELECT Count(*) FROM  "'||SchemaBuilding||'"."'||TableBuilding||'" as edif;';
 		  EXECUTE sql_query INTO NBuilding;
		  --  sql_query:= 'SELECT  Count(pob."'||IdPopulation||'" ) FROM  "'||SchemaPopulation||'"."'||TablePopulation||'" AS pob;';
		  --EXECUTE sql_query INTO NPopArea;
		 		

	 --SELECT POPULATION INSTERSECT WITH BUILDING  
	   sql_query:= 'SELECT DISTINCT Count(pob."'||IdPopulation||'") as "NPopArea",
	   					pob."'||IdPopulation||'"  as "IdPopulation", 
	     				pob."'||PopulationData||'"  as "PopulationData" ,  '||GeometryPopulation||'  as geom_pob 
						FROM "'||SchemaPopulation||'"."'||TablePopulation||'" AS pob, 
							 "'||SchemaBuilding||'"."'||TableBuilding||'" as edif
						WHERE '||GeometryPopulation||' && '||GeometryBuildingPU||' and st_intersects('||GeometryPopulation||','||GeometryBuildingPU||')
						GROUP BY pob."'||IdPopulation||'", pob."'||PopulationData||'" ,  '||GeometryPopulation||'';		
					
					-- raise notice'%',sql_query;

       open cursor_pob for EXECUTE sql_query; 
 	
	   -- EACH POPULATION IS PROCESS
		LOOP
			fetch cursor_pob into record_pob;
			IF record_pob is NULL THEN
				EXIT;
			END IF;
 			 Population:=record_pob."PopulationData";
			 CurrentIdPopulation:=record_pob."IdPopulation";	
			 CurrentGeometryPopulation:=record_pob."geom_pob";	
			 NPopArea:=record_pob."NPopArea";
			 
			--TOTAL ODF BUILDING IN EACH POPULATION AREA
 			
				--  SQL FILTER
					sql_query:='SELECT  count(edif."Area") as cuenta_edificios,
								sum(edif."Area") AS suma_edif_area,
								sum(edif.Volumen) as suma_edif_volumen,
								sum(edif."numberOfDwellings") as suma_edif_viviendas ,
								sum(edif."ResidentialArea") as suma_sup_residencial 
								FROM   results.results_bulding_'||uuid2||'  as edif ,"'||SchemaPopulation||'"."'||TablePopulation||'" AS pob ';
								--SIN FILTRO DE 
								
								sql_query_without_filter:= sql_query||' WHERE "'||IdPopulation||'" ='''||CurrentIdPopulation||''' 
								and ('||GeometryPopulation||' && edif.geom_pu) and st_intersects('||GeometryPopulation||' ,edif.geom_pu) ' ;
								--CON FILTRO DE USO		
								 sql_query_with_filter:=sql_query ||' WHERE "'||IdPopulation||'" ='''||CurrentIdPopulation||''' and "CurrentUse"='''||use_value||''' 
								 and ('||GeometryPopulation||' && edif.geom_pu)and st_intersects('||GeometryPopulation||' ,edif.geom_pu) ' ;	 

				 -- SQL SELECT BUILDING
					  sql_base:='SELECT id_buld, "Area",volumen, "numberOfDwellings", "ResidentialArea",edif.geom  FROM  results.results_bulding_'|| uuid2||'  as edif,
							     "'||SchemaPopulation||'"."'||TablePopulation||'" AS pob';					 	

			    -- CHECK USE FILTER
					IF UseFilter IS true THEN				
							EXECUTE sql_query_with_filter INTO record_sum_buil;  		
 							 sql_query:= sql_base||' WHERE (edif."CurrentUse"='''||use_value||''') and (pob."'||IdPopulation||'" ='''||CurrentIdPopulation||''' ) 
														 and ('||GeometryPopulation||' && edif.geom_pu) 
														 and st_intersects('||GeometryPopulation||' ,edif.geom_pu)' ;	

 					ELSE 					
						EXECUTE sql_query_without_filter INTO record_sum_buil; 	
 						sql_query:=sql_base||' WHERE "'||IdPopulation||'" ='''||CurrentIdPopulation||''' 
												  and ('||GeometryPopulation||'&& edif.geom_pu)
						                          and st_intersects('||GeometryPopulation||',edif.geom_pu)' ;	
 					END IF;
 

			 	 -- SELECT VALUES FOR THIS POPULATION AREA
				   TotalArea:=record_sum_buil.suma_edif_area;
				   TotalVolumen:=record_sum_buil.suma_edif_volumen;	
				   TotalDWellings:=record_sum_buil.suma_edif_viviendas;	
				   TotalResidencialArea:=record_sum_buil.suma_sup_residencial;
 			 
				 open cursor_building for EXECUTE sql_query;
 
				 -- EACH BUILDING 
				LOOP
					fetch cursor_building into record_building;
					 
					IF record_building is NULL  THEN
						EXIT;
					END IF;	
					
					BuildingArea:=COALESCE(record_building."Area", 0);  
					BuildingVolumen:=COALESCE(record_building.volumen, 0);
					BuildingDwellings:=COALESCE(record_building."numberOfDwellings", 0);					
					BuildingResidencialArea:=COALESCE(record_building."ResidentialArea", 0);

					--METODS
 						--Footprint
							IF (MetodFootprint IS TRUE)  and (TotalArea>0) THEN							 
								PopFootprint:=round((BuildingArea*Population/TotalArea)::numeric,6);
							ELSE
								PopFootprint:=0;		
							END IF;
						
						--VOLUMEN
							IF (MetodVolumen IS TRUE) and (TotalVolumen>0) THEN
								PopVolumen:=round((BuildingVolumen*Population/TotalVolumen)::numeric,6);		
							ELSE
								PopVolumen:=0;		
							END IF;	
						--WELLINGS									
							IF (MetodDWellings IS TRUE) and (TotalDWellings>0) THEN
								PopDwellings:=round((BuildingDwellings*Population/TotalDWellings)::numeric,6);		
							ELSE
								PopDwellings:=0;		
							END IF;								
						 -- RESIDENTIAL
							IF (MetodResidencialArea IS TRUE) and (TotalResidencialArea>0) THEN
								PopResidencialArea:=round((BuildingResidencialArea*Population/TotalResidencialArea)::numeric,6);		
							ELSE
								PopResidencialArea:=0;		
							END IF;			
 
							 
								sql_query:= 'UPDATE results.results_bulding_'||uuid2||' 
								                 SET Population='||Population||',
											     id_popu='''||CurrentIdPopulation||''', 
												 "popFootprint"='||PopFootprint||' , 
												"popVolumen"='||PopVolumen||' , 
												"popDwellings"='||PopDwellings||' , 
												"popResidentialArea"='||PopResidencialArea||' 							
												 WHERE id_buld='''||record_building.id_buld||''' ;';				
raise notice '%',sql_query ;
								EXECUTE sql_query; 
          
                        
 			  END LOOP;
			  close cursor_building;		
	END LOOP;
	close cursor_pob;
	/*
        --METADATA
		ProcessTime:= clock_timestamp()- ProcessTime;
		sql_query:= 'SELECT COUNT(*)  FROM  "'||SchemaPopulation||'"."'||TablePopulation||'" WHERE  "'||PopulationData||'" IS NULL OR  "'||PopulationData||'"=0';		
 
		EXECUTE sql_query INTO NZonaPopWithoutPop;	
 			 

 	  		sql_query:='SELECT SUM(pob_total) as pob_total  FROM (SELECT DISTINCT pob."'||PopulationData||'" as  pob_total 
			               FROM "'||SchemaPopulation||'"."'||TablePopulation||'" as pob, 
						    results.results_bulding_'||uuid2||' as edif
						    WHERE '||GeometryPopulation||'&& '||GeometryBuildingPU||' 
							and st_intersects('||GeometryPopulation||' ,'||GeometryBuildingPU||')) as a';				  
			 
			 EXECUTE sql_query INTO TotalPopulation; 

			--QUALITY FOOTPRINT			 
			 Footprint_NBuildingWithPop:=0;
			 Footprint_NBuildingWithoutPop:=0;
			 Footprint_NBuildingMore100Pop:=0;
			 FootprintPopFinal:=0;		 
 			    sql_query:='SELECT "POPIMPACT"."_Metadata_NBuildingsWithtPop"('''||uuid2||'''::text,''popFootprint''::text,'||UseFilter||','''||use_value||'''::text)';
			  	EXECUTE  sql_query INTO Footprint_NBuildingWithPop;
				sql_query:='SELECT "POPIMPACT"."_Metadata_NBuildingsWithoutPop"('''||uuid2||'''::text,''popFootprint''::text,'||UseFilter||','''||use_value||'''::text)';
				EXECUTE  sql_query INTO  Footprint_NBuildingWithoutPop;
				sql_query:='SELECT "POPIMPACT"."_Metadata_NBuildingsPop100"('''||uuid2||'''::text, ''popFootprint''::text)';
				EXECUTE  sql_query INTO 	Footprint_NBuildingMore100Pop;				
				sql_query:='SELECT  "POPIMPACT"."_Metadata_CurrentPopulation"('''||uuid2||'''::text, ''popFootprint''::text)';
				EXECUTE  sql_query INTO CurrentPopFootprint; 
				FootprintPopFinal:= TotalPopulation-CurrentPopFootprint;
				
	        --QUALITY VOLUMEN	
			 Volumen_NBuildingWithPop:=0;
			 Volumen_NBuildingWithoutPop:=0;
			 Volumen_NBuildingMore100Pop:=0;
			 VolumenPopFinal:=0;			 
  			    sql_query:='SELECT "POPIMPACT"."_Metadata_NBuildingsWithtPop"('''||uuid2||''',''popVolumen''::text,'||UseFilter||','''||use_value||''')';
			  	EXECUTE  sql_query INTO Volumen_NBuildingWithPop;
				sql_query:='SELECT "POPIMPACT"."_Metadata_NBuildingsWithoutPop"('''||uuid2||''',''popVolumen''::text,'||UseFilter||','''||use_value||''')';
				EXECUTE  sql_query INTO  Volumen_NBuildingWithoutPop;
				sql_query:='SELECT  "POPIMPACT"."_Metadata_NBuildingsPop100"('''||uuid2||''', ''popVolumen''::text) ';
				EXECUTE  sql_query INTO Volumen_NBuildingMore100Pop;
				sql_query:='SELECT  "POPIMPACT"."_Metadata_CurrentPopulation"('''||uuid2||''', ''popVolumen''::text) ';
				EXECUTE  sql_query INTO CurrentPopVolumen;  
				VolumenPopFinal:= TotalPopulation-CurrentPopVolumen;			
			 
			--QUALITY WELLING	
 			 Dwellings_NBuildingWithPop:=0;
			 Dwellings_NBuildingWithoutPop:=0;
			 Dwellings_NBuildingMore100Pop:=0;
			 DwellingsPopFinal:=0;
			    sql_query:='SELECT "POPIMPACT"."_Metadata_NBuildingsWithtPop"('''||uuid2||''',''popDwellings''::text,'||UseFilter||','''||use_value||''')'; 
			  	EXECUTE  sql_query INTO Dwellings_NBuildingWithPop;
				sql_query:='SELECT "POPIMPACT"."_Metadata_NBuildingsWithoutPop"('''||uuid2||''',''popDwellings''::text,'||UseFilter||','''||use_value||''')';
				EXECUTE  sql_query INTO  Dwellings_NBuildingWithoutPop;			  
				sql_query:='SELECT  "POPIMPACT"."_Metadata_NBuildingsPop100"('''||uuid2||''',''popDwellings''::text) ';
				EXECUTE  sql_query   INTO Dwellings_NBuildingMore100Pop;
				sql_query:='SELECT   "POPIMPACT"."_Metadata_CurrentPopulation"('''||uuid2||''',''popDwellings''::text) ';
				EXECUTE  sql_query INTO  CurrentPopDwellings;  
				DwellingsPopFinal:= TotalPopulation-CurrentPopDwellings;
 
			--QUALITY RESIDENTIAL	
		 	 ResidencialArea_NBuildingWithPop:=0;
			 ResidencialArea_NBuildingWithoutPop:=0;
			 ResidencialArea_NBuildingMore100Pop:=0;
			 ResidencialAreaPopFinal:=0;	
			    sql_query:='SELECT "POPIMPACT"."_Metadata_NBuildingsWithtPop"('''||uuid2||''',''popResidentialArea''::text,'||UseFilter||','''||use_value||''')'; 
			  	EXECUTE  sql_query INTO ResidencialArea_NBuildingWithPop;
				sql_query:='SELECT  "POPIMPACT"."_Metadata_NBuildingsWithoutPop"('''||uuid2||''',''popResidentialArea''::text,'||UseFilter||','''||use_value||''')';
				EXECUTE  sql_query INTO  ResidencialArea_NBuildingWithoutPop; 		 		  
				sql_query:='SELECT  "POPIMPACT"."_Metadata_NBuildingsPop100"('''||uuid2||''',''popResidentialArea''::text)';				
				EXECUTE  sql_query INTO ResidencialArea_NBuildingMore100Pop;
				sql_query:='SELECT   "POPIMPACT"."_Metadata_CurrentPopulation"('''||uuid2||''',''popResidentialArea''::text)';				
				EXECUTE  sql_query INTO  CurrentPopResidencialArea;  
				ResidencialAreaPopFinal:= TotalPopulation-CurrentPopResidencialArea;
 				
			 --FILTER BUILDINGS
				sql_query_metadata:='SELECT count(*) as cuenta_edificios FROM  results.results_bulding_'||uuid2||' as edif WHERE  "CurrentUse"='''||use_value||'''';
 				EXECUTE sql_query_metadata INTO NBuildingFilter;
				
				sql_query_metadata:='SELECT count(*) as cuenta_edificios FROM  results.results_bulding_'||uuid2||' as edif WHERE  "CurrentUse"!='''||use_value||''' OR "CurrentUse" is null';
 				EXECUTE sql_query_metadata INTO NBuildingWithoutFilter; 
				
			metadate_json:='{"Proceso":{"IdProcess":"'||(json_in->'Process'->>'IdProcess')||'","ProcessDate":"'||now()||'","ProcessTime":"'||ProcessTime||'","EPSG": '||EPSGProyect||',"FootMethod":"'||MetodFootprint||'","VolumenMethod":"'||MetodVolumen||'","DWellingMethod":"'||MetodDWellings||'","SupResidencialMethod":"'||MetodResidencialArea||'","Scope":"'||Ambit||'","epsg":'||EPSGProyect||'},"OriginDate":[{"IdOriginData":"'||IdBuilding||'","NameOriginData":"'||TableBuilding||'","epsg":'||EPSGBuilding||'},{"IdOriginData":"'||IdPopulation||'","OriginDataName":"'||TablePopulation||'","epsg":'||EPSGPopulation||'}],"lineage":[{"Step":1,"name":"Pasar a puntos la capa de edificios y armonizar los nombre de los atributos y epsg"},{"step":2,"name":"Se intersecta los edificios puntuales( centro de gravedad) con los recintos de Population y se n_count la Population total, area, volumen, sup. residencia y número totales de edicios"},{"step":3,"name":"Se recorren los edificos de cada zona de población y se asigna la población de los métodos selcionados, al último registro se le asigna los valores de resto" }],"Calidad":{"NBuilding":'||NBuilding||',"NPopArea":'||NPopArea||', "NZonaPopWithoutPop":'||NZonaPopWithoutPop||',"NBuildingFilter":'||NBuildingFilter||',"NBuildingWithoutFilter":'||NBuildingWithoutFilter||',"TotalPopulation":'||TotalPopulation||'},"CalidadMetodoHuella":{"NEdificiosConPob":'||Footprint_NBuildingWithPop||',"NEdificiosSinPob":'||Footprint_NBuildingWithoutPop||',"NBuildingMore100Pop":'||Footprint_NBuildingMore100Pop||',"PobNoAsignada":'||FootprintPopFinal||'},"CalidadMetodoVolumen":{"NEdificiosConPob":'||Volumen_NBuildingWithPop||',"NEdificiosSinPob":'||Volumen_NBuildingWithoutPop||',"NBuildingMore100Pop":'||Volumen_NBuildingMore100Pop||',"PobNoAsignada":'||VolumenPopFinal||'},"CalidadMetodoNViviendas":{"NEdificiosConPob":'||Dwellings_NBuildingWithPop||',"NEdificiosSinPob":'||Dwellings_NBuildingWithoutPop||',"NBuildingMore100Pop":'||Dwellings_NBuildingMore100Pop||',"PobNoAsignada":'||DwellingsPopFinal||'},"CalidadMetodoSupResidencial":{"NEdificiosConPob":'||ResidencialArea_NBuildingWithPop||',"NEdificiosSinPob":'||ResidencialArea_NBuildingWithoutPop||',"NBuildingMore100Pop":'||ResidencialArea_NBuildingMore100Pop||',"PobNoAsignada":'||ResidencialAreaPopFinal||'}}';
			sql_query:= 'INSERT INTO results.results_metadata( metadato)VALUES ('''||metadate_json||''');';				
			--EXECUTE sql_query; 
            */
            
 	END;	

$_$;


ALTER FUNCTION "Process"."_DisaggregatePopulationBuildings"(json) OWNER TO postgres;

--
-- TOC entry 4340 (class 0 OID 0)
-- Dependencies: 952
-- Name: FUNCTION "_DisaggregatePopulationBuildings"(json); Type: COMMENT; Schema: Process; Owner: postgres
--

COMMENT ON FUNCTION "Process"."_DisaggregatePopulationBuildings"(json) IS 'Function that is responsible for assig the population to building
JSON EXAMPLE:
(''{"Process":{"IdProcess":"124a9cad-6d21-4037-a362-f41821d35054","MetodFootprint":"True","MetodVolumen":"True","MetodDWellings":"True","MetodResidencialArea":"False","UseFilter":"True","epsg":3035,"BuildingFilter":"False"},"BuildingData":{"Id":1,"SchemaName":"bulding_pop","TableName":"building","IdData":"localId","epsg":25830,"geometry":"geom","useField":"currentUse","useValue":"1_residential","area":"True","area_calculate":"True","area_field":"","volumen":"True","volumen_calculate":"True","volumen_type":"Floor","volumen_field":"numberOfFloorsAboveGround","Dwellings":"True","Dwellings_field":"numberOfDwellings","residential_area":"False","residential_area_field":""},"PopulationData":{"Id":2,"SchemaName":"bulding_pop","TableName":"JRC_POPULATION_2018","Id":"grd_id","epsg":3035,"geometry":"geom","PopulationField":"tot_p_2018"}}''::json);
';


--
-- TOC entry 953 (class 1255 OID 2758161)
-- Name: _Metadata_CurrentPopulation(text, text); Type: FUNCTION; Schema: Process; Owner: postgres
--

CREATE FUNCTION "Process"."_Metadata_CurrentPopulation"(uuid text, field text) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
   
	DECLARE
 	sql_query text;
	results integer;

	BEGIN
   
		 sql_query:= 'SELECT  SUM("'||$2||'")::integer as '||$2||'  FROM results.results_bulding_'||$1;
		 
		EXECUTE sql_query INTO results;			 
		return results;
	
			 
 	END;

$_$;


ALTER FUNCTION "Process"."_Metadata_CurrentPopulation"(uuid text, field text) OWNER TO postgres;

--
-- TOC entry 956 (class 1255 OID 2758162)
-- Name: _Metadata_NBuildingsPop100(text, text); Type: FUNCTION; Schema: Process; Owner: postgres
--

CREATE FUNCTION "Process"."_Metadata_NBuildingsPop100"(uuid text, field text) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
   
	DECLARE
 	sql_query text;
	results integer;

	BEGIN
   
		 sql_query:= 'SELECT COUNT(*)::integer  FROM results.results_bulding_'||$1||' 
		             WHERE  ("'||$2||'"!= 0 OR "'||$2||'" IS NOT NULL) AND "'||$2||'"> 100';
		  
		 
		EXECUTE sql_query INTO results;			 
		return results;
			 
 	END;

$_$;


ALTER FUNCTION "Process"."_Metadata_NBuildingsPop100"(uuid text, field text) OWNER TO postgres;

--
-- TOC entry 954 (class 1255 OID 2758170)
-- Name: _Metadata_NBuildingsWithoutPop(text, text, boolean, text); Type: FUNCTION; Schema: Process; Owner: postgres
--

CREATE FUNCTION "Process"."_Metadata_NBuildingsWithoutPop"(uuid text, field text, usefilter boolean, usevalue text) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
   
	DECLARE
   sql_query text;
	results integer;

	BEGIN
		IF $3 IS true THEN
		 sql_query:='SELECT COUNT("'||$2||'")::integer FROM results.results_bulding_'||$1||' WHERE ("CurrentUse"='''||$4||''') and "'||$2||'"=0 ';

		 ELSE 
		 sql_query:='SELECT COUNT("'||$2||'")::integer FROM results.results_bulding_'||$1||' WHERE "'||$2||'"=0 ';

		 END IF;
		 
					
		EXECUTE sql_query INTO results;			 
		return results;
			 
			 
 	END;

$_$;


ALTER FUNCTION "Process"."_Metadata_NBuildingsWithoutPop"(uuid text, field text, usefilter boolean, usevalue text) OWNER TO postgres;

--
-- TOC entry 955 (class 1255 OID 2758171)
-- Name: _Metadata_NBuildingsWithtPop(text, text, boolean, text); Type: FUNCTION; Schema: Process; Owner: postgres
--

CREATE FUNCTION "Process"."_Metadata_NBuildingsWithtPop"(uuid text, field text, usefilter boolean, usevalue text) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
   
	DECLARE
 	sql_query text;
	results integer;
	
	BEGIN
		IF $3 IS true THEN
		 sql_query:='SELECT COUNT("'||$2||'")::integer  FROM results.results_bulding_'||$1||' WHERE ("CurrentUse"='''||$4||''') and "'||$2||'"<>0 ';

		 ELSE 
		 sql_query:='SELECT COUNT("'||$2||'")::integer  FROM results.results_bulding_'||$1||' WHERE "'||$2||'"<>0 ';

		 END IF;
		 
		EXECUTE sql_query INTO results;			 
		return results;
	
			 
 	END;

$_$;


ALTER FUNCTION "Process"."_Metadata_NBuildingsWithtPop"(uuid text, field text, usefilter boolean, usevalue text) OWNER TO postgres;

--
-- TOC entry 957 (class 1255 OID 2758172)
-- Name: _NormalizeBuildings(json); Type: FUNCTION; Schema: Process; Owner: postgres
--

CREATE FUNCTION "Process"."_NormalizeBuildings"(json) RETURNS void
    LANGUAGE plpgsql
    AS $_$
  
	DECLARE
	-- PARSER JSON
		json_in json;
		EPSGProyect integer;
		uuid text;
		uuid_origen uuid;
		
		--POPULATION
		SchemaPopulation  text;
		TablePopulation  text;
		GeometryPopulation  text;
		EPSGPopulation integer;		
		
		--BUILDING
		SchemaBuilding  text;
		TableBuilding   text;
		GeometryBuilding  text;
		GeometryBuildingPU  text;
		EPSGBuilding integer;
		IdBuilding text;	

		area boolean;
		area_calculate boolean;
		area_field text;
		
		volumen boolean;		
		volumen_calculate boolean;
		volumen_type text;
		volumen_field text;	
		
		dwellings boolean;
		dwellings_field text;	
		
		sup_residencial boolean;
		sup_residencial_field text;
		
		use_field text;
		sql_query text;		
		use_filter boolean;
		
		--FILTER
	    Building_filter boolean;
		SchemaFilter text;
		TableFilter text;
		GeometryFilter text;
		EPSGFilter integer; 		
		sql_query_filter text;

		numberOfFloorsAboveGround text;
		endLifespanVersion text;
		beginLifespanVersion text;
		localId text;
		name_space text;
		conditionOfConstruction text;
		inspireId text;
		referenceGeometry text;
		numberOfBuildingUnits text;
		
 		t timestamp;

	BEGIN
	
	--CONTADOR DE TIEMPO
	  t:= clock_timestamp();
	
	--PARSER INPUT	    
		json_in:=$1::json;
	    EPSGProyect:=(json_in->'Process'->>'epsg')::integer; 
        uuid:=REPLACE((json_in->'Process'->>'IdProcess'),'-', '_');
		uuid_origen:=(json_in->'Process'->>'IdProcess')::uuid;
		
		SchemaBuilding:=(json_in->'BuildingData'->>'SchemaName')::text;
		TableBuilding:=(json_in->'BuildingData'->>'TableName')::text;
		GeometryBuilding:=(json_in->'BuildingData'->>'geometry')::text; 
		EPSGBuilding:=(json_in->'BuildingData'->>'epsg')::integer; 
		IdBuilding:=(json_in->'BuildingData'->>'IdData')::text;
	 
		area:=(json_in->'BuildingData'->>'area')::boolean;
		area_calculate:=(json_in->'BuildingData'->>'area_calculate')::boolean;
		area_field:=(json_in->'BuildingData'->>'area_field')::text;
	    		
		volumen:=(json_in->'BuildingData'->>'volumen')::boolean;
		volumen_calculate:=(json_in->'BuildingData'->>'volumen_calculate')::boolean;
		volumen_type:=(json_in->'BuildingData'->>'volumen_type')::text;
		volumen_field:=(json_in->'BuildingData'->>'volumen_field')::text;	
		
	    dwellings:=(json_in->'BuildingData'->>'Dwellings')::boolean; 
		dwellings_field:=(json_in->'BuildingData'->>'Dwellings_field')::text;	
		
		sup_residencial:=(json_in->'BuildingData'->>'residential_area')::boolean; 
		sup_residencial_field:=(json_in->'BuildingData'->>'residential_area_field')::text;		
 		
		use_filter:=(json_in->'Process'->>'UseFilter')::boolean;
		Building_filter:=(json_in->'Process'->>'BuildingFilter')::boolean;
		SchemaFilter:=(json_in->'FilterData'->>'SchemaName')::text;
		TableFilter:=(json_in->'FilterData'->>'TableName')::text;
		GeometryFilter:=(json_in->'FilterData'->>'geometry')::text; 
		EPSGFilter:=(json_in->'FilterData'->>'epsg')::integer; 
        use_field:=(json_in->'BuildingData'->>'useField')::text; 
	
		numberOfFloorsAboveGround:=(json_in->'BuildingData'->>'numberOfFloorsAboveGround')::text; 
		endLifespanVersion:=(json_in->'BuildingData'->>'endLifespanVersion')::text; 
		beginLifespanVersion:=(json_in->'BuildingData'->>'beginLifespanVersion')::text; 
		localId:=(json_in->'BuildingData'->>'fid')::text; 
		name_space:=(json_in->'BuildingData'->>'namespace')::text; 
		conditionOfConstruction:=(json_in->'BuildingData'->>'conditionOfConstruction')::text; 
		inspireId:=(json_in->'BuildingData'->>'inspireId')::text ; 
		referenceGeometry:=(json_in->'BuildingData'->>'referenceGeometry')::text; 
		numberOfBuildingUnits:=(json_in->'BuildingData'->>'numberOfBuildingUnits')::text; 		 		
		use_field:=(json_in->'BuildingData'->>'useField')::text; 
		
	--CHECK LAYERS´S EPSG
		If EPSGBuilding!= EPSGProyect then  
	   	  GeometryBuilding:='st_transform((ST_Dump(edif."'||GeometryBuilding||'")).geom, '||EPSGProyect||')';	
		  GeometryBuildingPU:='st_transform(ST_PointOnSurface((ST_Dump(edif."'||GeometryBuilding||'")).geom),
		  '||EPSGProyect||')';	
	    ELSE 
	      GeometryBuilding:='(ST_Dump(edif."'||GeometryBuilding||'")).geom ';
		  GeometryBuildingPU:='ST_PointOnSurface('||GeometryBuilding||')';		    
	    END IF;
		 
	   
	-- CREATE TABLE RESULTS
		 sql_query:='DROP TABLE IF EXISTS results.results_bulding_'|| uuid;
		 EXECUTE sql_query;

		 sql_query:='CREATE TABLE results.results_bulding_'|| uuid||'  
					 AS SELECT id, id_process, id_buld, id_popu,   "CurrentUse",population, "popFootprint", "popVolumen",
					 "popDwellings", "popResidentialArea", "Area",elevation, Volumen, "numberOfDwellings",
					 "ResidentialArea","numberOfFloorsAboveGround","endLifespanVersion","beginLifespanVersion",
					 "localId","namespace","conditionOfConstruction","inspireId","referenceGeometry",
					 "numberOfBuildingUnits", geom, geom_pu ';

	 If Building_filter IS TRUE THEN 
	  sql_query:=sql_query||',filter_geom';
	 END IF;

raise notice 'hola 1 %',inspireId;
	 sql_query:=sql_query||' FROM (SELECT 	ROW_NUMBER () OVER () as id,
	    0 as "numberOfFloorsAboveGround",
	   '''' as "endLifespanVersion",
		''''as "beginLifespanVersion",  
		''ES.SDGC.BU''::text as "namespace",
		''functional'' as "conditionOfConstruction",
		''''::text as id_popu,
		1 as "referenceGeometry",
		1 as "numberOfBuildingUnits",
		'''|| uuid_origen||''' as id_process, 
		fid as "inspireId",	
		 fid as "localId",			    
		  fid as id_buld ,
		';
	
	 	

	 IF (use_filter IS True)  THEN	 	 	
	 sql_query:=sql_query||'"'|| use_field||'" as "CurrentUse" ';
	 ELSE
	 sql_query:=sql_query||'''Unknown'' as "CurrentUse"'; 
	 END IF;
	
	
     If Building_filter IS TRUE THEN
     sql_query:=sql_query|| ', filter."'|| GeometryFilter||'" as filter_geom';
 	 end if;
	 
	sql_query:=sql_query||', '|| GeometryBuilding||' as geom,'|| GeometryBuildingPU||' as geom_pu ,
	0::numeric as "population", 0::numeric as "popFootprint", 0::numeric as "popVolumen",
	0::numeric as "popDwellings", 0::numeric as "popResidentialArea"';
	 
	
	--CALCULO DEL AREA
	 If area is true  THEN 
		  If area_calculate is true THEN					 
			sql_query:=sql_query ||', st_area('|| GeometryBuilding||')  as "Area"';
		  ELSE
			sql_query:=sql_query ||','|| area_field||' as "Area"';
		  END IF;	
	 ELSE
	 	sql_query:=sql_query ||', 0::numeric  as  "Area"';		  
	 END IF;
	--VOLUMEN
	
	If volumen is true  THEN	 
		sql_query:=sql_query ||', COALESCE(edif."'|| volumen_field||'"::numeric,0) as elevation, 
		COALESCE(st_area('|| GeometryBuilding||')::numeric,0)*';		
			
			IF volumen_type= 'Floor' THEN
				sql_query:=sql_query ||'("'|| volumen_field||'"::integer*3)) as "Volumen"';
			ELSE 
				sql_query:=sql_query ||'"'|| volumen_field||'" as "volumen"';
			END IF;
		 
	ELSE
	 	sql_query:=sql_query ||', 0::numeric  as  elevation, 0  as  "volumen"';	 
	END IF;

 	--DWELLINGS
		 If dwellings is true  THEN 
				 sql_query:=sql_query ||',edif."'|| dwellings_field||'"  as "numberOfDwellings"';
		ELSE
				 sql_query:=sql_query ||',0::numeric  as  "numberOfDwellings"';			
		 END IF; 

 	--  SUP. RESIDENCIAL AREA
		 If sup_residencial is true  THEN 
				 sql_query:=sql_query ||',edif."'|| sup_residencial_field||'"  as  "ResidentialArea"';		
		 ELSE
				 sql_query:=sql_query ||',0::numeric as  "ResidentialArea"';	
		 END IF;   

	---FILTER LAYER
		If Building_filter IS TRUE THEN 
		
			If EPSGFilter=EPSGProyect THEN			
				sql_query:=sql_query ||' FROM  "'||SchemaBuilding||'"."'||TableBuilding||'" as edif , 
				"'||SchemaFilter||'"."'||TableFilter||'" as filtro WHERE  
				(edif."'||NombreGeometryBuilding||'" && filtro."'||GeometryFilter||'") AND 
				ST_Intersects(edif."'||NombreGeometryBuilding||'",filtro."'||GeometryFilter||'")';
			
			  sql_query_filter:= ')AS A WHERE (geom&&st_transform(filter_geom,'||EPSGProyect||')) AND
				ST_Intersects(geom,st_transform(filter_geom,'||EPSGProyect||'))';			   
			   sql_query:=sql_query ||sql_query_filtro ;
 			ELSE 
			sql_query:=sql_query ||' FROM  "'||SchemaBuilding||'"."'||TableBuilding||'" as edif , 
			as filtro WHERE ( edif."'||NombreGeometryBuilding||'" && st_transform(filtro."'||GeometryFilter||'","'||EPSGProyect||'")
			AND ST_Intersects( edif."'||NombreGeometryBuilding||'" , st_transform(filtro."'||GeometryFilter||'","'||EPSGProyect||'")';
			sql_query_filter:= ')AS A WHERE (geom&&filter_geom) AND ST_Intersects(geom,filter_geom))) as tabla2';
		     sql_query:=sql_query ||sql_query_filtro ;
        END IF;	
		
		ELSE
			sql_query:=sql_query ||' FROM  "'||SchemaBuilding||'"."'||TableBuilding||'" as edif ) as a ';	
		END IF;
			  
	 EXECUTE sql_query;
		 
		 
	END; 
 
	
$_$;


ALTER FUNCTION "Process"."_NormalizeBuildings"(json) OWNER TO postgres;

--
-- TOC entry 4341 (class 0 OID 0)
-- Dependencies: 957
-- Name: FUNCTION "_NormalizeBuildings"(json); Type: COMMENT; Schema: Process; Owner: postgres
--

COMMENT ON FUNCTION "Process"."_NormalizeBuildings"(json) IS 'Function that is responsible for normalising the input data to the Inspire building model.
JSON EXAMPLE:
(''{"Process":{"IdProcess":"124a9cad-6d21-4037-a362-f41821d35054","MetodFootprint":"True","MetodVolumen":"True","MetodDWellings":"True","MetodResidencialArea":"False","UseFilter":"True","epsg":3035,"BuildingFilter":"False"},"BuildingData":{"Id":1,"SchemaName":"bulding_pop","TableName":"building","IdData":"localId","epsg":25830,"geometry":"geom","useField":"currentUse","useValue":"1_residential","area":"True","area_calculate":"True","area_field":"","volumen":"True","volumen_calculate":"True","volumen_type":"Floor","volumen_field":"numberOfFloorsAboveGround","Dwellings":"True","Dwellings_field":"numberOfDwellings","residential_area":"False","residential_area_field":""},"PopulationData":{"Id":2,"SchemaName":"bulding_pop","TableName":"JRC_POPULATION_2018","Id":"grd_id","epsg":3035,"geometry":"geom","PopulationField":"tot_p_2018"}}''::json);
';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 228 (class 1259 OID 2758280)
-- Name: Countries; Type: TABLE; Schema: OriginData; Owner: postgres
--

CREATE TABLE "OriginData"."Countries" (
    id integer NOT NULL,
    geom public.geometry(MultiPolygon,4326),
    cntr_id character varying(2),
    cntr_name character varying(159),
    name_engl character varying(44),
    iso3_code character varying(3),
    fid character varying(2)
);


ALTER TABLE "OriginData"."Countries" OWNER TO postgres;

--
-- TOC entry 229 (class 1259 OID 2758285)
-- Name: Countries_id_seq; Type: SEQUENCE; Schema: OriginData; Owner: postgres
--

CREATE SEQUENCE "OriginData"."Countries_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "OriginData"."Countries_id_seq" OWNER TO postgres;

--
-- TOC entry 4342 (class 0 OID 0)
-- Dependencies: 229
-- Name: Countries_id_seq; Type: SEQUENCE OWNED BY; Schema: OriginData; Owner: postgres
--

ALTER SEQUENCE "OriginData"."Countries_id_seq" OWNED BY "OriginData"."Countries".id;


--
-- TOC entry 230 (class 1259 OID 2758286)
-- Name: JRC_POPULATION_2018; Type: TABLE; Schema: OriginData; Owner: postgres
--

CREATE TABLE "OriginData"."JRC_POPULATION_2018" (
    id integer NOT NULL,
    geom public.geometry(MultiPolygon,3035),
    objectid bigint,
    grd_id character varying(254),
    cntr_id character varying(254),
    tot_p_2018 bigint,
    country character varying(2),
    date character varying(10),
    method character varying(50),
    shape_leng double precision,
    shape_area double precision
);


ALTER TABLE "OriginData"."JRC_POPULATION_2018" OWNER TO postgres;

--
-- TOC entry 231 (class 1259 OID 2758296)
-- Name: JRC_POPULATION_2018_id_seq; Type: SEQUENCE; Schema: OriginData; Owner: postgres
--

CREATE SEQUENCE "OriginData"."JRC_POPULATION_2018_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "OriginData"."JRC_POPULATION_2018_id_seq" OWNER TO postgres;

--
-- TOC entry 4343 (class 0 OID 0)
-- Dependencies: 231
-- Name: JRC_POPULATION_2018_id_seq; Type: SEQUENCE OWNED BY; Schema: OriginData; Owner: postgres
--

ALTER SEQUENCE "OriginData"."JRC_POPULATION_2018_id_seq" OWNED BY "OriginData"."JRC_POPULATION_2018".id;


--
-- TOC entry 232 (class 1259 OID 2758303)
-- Name: building_seville; Type: TABLE; Schema: OriginData; Owner: postgres
--

CREATE TABLE "OriginData".building_seville (
    id integer NOT NULL,
    geom public.geometry(MultiPolygon,25830),
    gml_id character varying,
    "beginLifespanVersion" character varying(19),
    "conditionOfConstruction" character varying(10),
    beginning character varying(19),
    "end" character varying(19),
    "endLifespanVersion" character varying(19),
    "informationSystem" character varying(92),
    reference character varying(14),
    "localId" character varying(14),
    namespace character varying(10),
    "horizontalGeometryEstimatedAccuracy" double precision,
    "horizontalGeometryEstimatedAccuracy_uom" character varying(1),
    "horizontalGeometryReference" character varying(9),
    "referenceGeometry" boolean,
    "currentUse" character varying(18),
    "numberOfBuildingUnits" integer,
    "numberOfDwellings" integer,
    "numberOfFloorsAboveGround" character varying,
    "documentLink" character varying(128),
    format character varying(4),
    "sourceStatus" character varying(11),
    "officialAreaReference" character varying(14),
    value integer,
    value_uom character varying(2)
);


ALTER TABLE "OriginData".building_seville OWNER TO postgres;

--
-- TOC entry 233 (class 1259 OID 2758320)
-- Name: edificios_la_palma; Type: TABLE; Schema: OriginData; Owner: postgres
--

CREATE TABLE "OriginData".edificios_la_palma (
    id integer NOT NULL,
    geom public.geometry(MultiPolygon,4326),
    gml_id character varying(254),
    beginlifes character varying(24),
    conditiono character varying(254),
    beginning character varying(24),
    "end" character varying(24),
    endlifespa character varying(24),
    informatio character varying(254),
    reference character varying(254),
    localid character varying(254),
    namespace character varying(254),
    horizontal numeric,
    horizont_1 character varying(254),
    horizont_2 character varying(254),
    referenceg integer,
    currentuse character varying(254),
    numberofbu bigint,
    numberofdw bigint,
    numberoffl character varying(254),
    documentli character varying(254),
    format character varying(254),
    sourcestat character varying(254),
    officialar character varying(254),
    value bigint,
    value_uom character varying(254),
    layer character varying(254),
    path character varying(254)
);


ALTER TABLE "OriginData".edificios_la_palma OWNER TO postgres;

--
-- TOC entry 234 (class 1259 OID 2758325)
-- Name: edificios_la_palma_id_seq; Type: SEQUENCE; Schema: OriginData; Owner: postgres
--

CREATE SEQUENCE "OriginData".edificios_la_palma_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "OriginData".edificios_la_palma_id_seq OWNER TO postgres;

--
-- TOC entry 4344 (class 0 OID 0)
-- Dependencies: 234
-- Name: edificios_la_palma_id_seq; Type: SEQUENCE OWNED BY; Schema: OriginData; Owner: postgres
--

ALTER SEQUENCE "OriginData".edificios_la_palma_id_seq OWNED BY "OriginData".edificios_la_palma.id;


--
-- TOC entry 235 (class 1259 OID 2758326)
-- Name: fr_edificios; Type: TABLE; Schema: OriginData; Owner: postgres
--

CREATE TABLE "OriginData".fr_edificios (
    id integer NOT NULL,
    geom public.geometry(MultiPolygon,2154),
    fid bigint,
    "TYPE" character varying(21),
    layer character varying,
    path character varying
);


ALTER TABLE "OriginData".fr_edificios OWNER TO postgres;

--
-- TOC entry 236 (class 1259 OID 2758336)
-- Name: fr_edificios_id_seq; Type: SEQUENCE; Schema: OriginData; Owner: postgres
--

CREATE SEQUENCE "OriginData".fr_edificios_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "OriginData".fr_edificios_id_seq OWNER TO postgres;

--
-- TOC entry 4345 (class 0 OID 0)
-- Dependencies: 236
-- Name: fr_edificios_id_seq; Type: SEQUENCE OWNED BY; Schema: OriginData; Owner: postgres
--

ALTER SEQUENCE "OriginData".fr_edificios_id_seq OWNED BY "OriginData".fr_edificios.id;


--
-- TOC entry 237 (class 1259 OID 2758343)
-- Name: palma_pob; Type: TABLE; Schema: OriginData; Owner: postgres
--

CREATE TABLE "OriginData".palma_pob (
    id integer NOT NULL,
    geom public.geometry(MultiPolygon,4326),
    objectid bigint,
    geocode character varying(254),
    etiqueta character varying(254),
    granularid character varying(254),
    gcd_isla character varying(254),
    gcd_munici character varying(254),
    superficie numeric,
    utm_x numeric,
    utm_y numeric,
    longitud numeric,
    latitud numeric,
    fecha character varying(24),
    geoparent bigint,
    gcd_gcomar character varying(254),
    gcd_comarc character varying(254),
    gcd_muni_1 bigint,
    poblacion bigint,
    poblacion_ numeric,
    poblacion1 bigint,
    poblacio_1 bigint,
    poblacio_2 numeric,
    poblacio_3 bigint,
    poblacio_4 bigint,
    poblacio_5 numeric,
    poblacio_6 bigint,
    poblacio_7 bigint,
    poblacio_8 bigint,
    poblacio_9 numeric,
    poblaci_10 numeric,
    poblaci_11 numeric,
    poblaci_12 numeric,
    poblaci_13 numeric,
    poblaci_14 numeric,
    poblaci_15 numeric,
    poblaci_16 numeric,
    superfic_1 numeric,
    poblaci_17 numeric,
    poblaci_18 numeric,
    poblaci_19 bigint,
    poblaci_20 bigint,
    poblaci_21 bigint,
    poblaci_22 numeric,
    poblaci_23 numeric,
    poblaci_24 numeric,
    municipio character varying(254),
    shape__are numeric,
    shape__len numeric
);


ALTER TABLE "OriginData".palma_pob OWNER TO postgres;

--
-- TOC entry 238 (class 1259 OID 2758348)
-- Name: palma_pob_id_seq; Type: SEQUENCE; Schema: OriginData; Owner: postgres
--

CREATE SEQUENCE "OriginData".palma_pob_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "OriginData".palma_pob_id_seq OWNER TO postgres;

--
-- TOC entry 4346 (class 0 OID 0)
-- Dependencies: 238
-- Name: palma_pob_id_seq; Type: SEQUENCE OWNED BY; Schema: OriginData; Owner: postgres
--

ALTER SEQUENCE "OriginData".palma_pob_id_seq OWNED BY "OriginData".palma_pob.id;


--
-- TOC entry 239 (class 1259 OID 2758355)
-- Name: perimetros_coladas; Type: TABLE; Schema: OriginData; Owner: postgres
--

CREATE TABLE "OriginData".perimetros_coladas (
    id integer NOT NULL,
    geom public.geometry(MultiPolygon,4326),
    "OBJECTID" integer,
    area double precision,
    "Perimetro" integer,
    fecha integer,
    fecha_2 timestamp without time zone,
    ha character varying,
    "Shape__Area" double precision,
    "Shape__Length" double precision
);


ALTER TABLE "OriginData".perimetros_coladas OWNER TO postgres;

--
-- TOC entry 240 (class 1259 OID 2758360)
-- Name: perimetros_coladas_id_seq; Type: SEQUENCE; Schema: OriginData; Owner: postgres
--

CREATE SEQUENCE "OriginData".perimetros_coladas_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "OriginData".perimetros_coladas_id_seq OWNER TO postgres;

--
-- TOC entry 4347 (class 0 OID 0)
-- Dependencies: 240
-- Name: perimetros_coladas_id_seq; Type: SEQUENCE OWNED BY; Schema: OriginData; Owner: postgres
--

ALTER SEQUENCE "OriginData".perimetros_coladas_id_seq OWNED BY "OriginData".perimetros_coladas.id;


--
-- TOC entry 241 (class 1259 OID 2758361)
-- Name: pob_palma_afectada; Type: TABLE; Schema: OriginData; Owner: postgres
--

CREATE TABLE "OriginData".pob_palma_afectada (
    id bigint NOT NULL,
    geom public.geometry(MultiPolygon,4326),
    geocode character varying(254),
    poblacion numeric
);


ALTER TABLE "OriginData".pob_palma_afectada OWNER TO postgres;

--
-- TOC entry 242 (class 1259 OID 2758371)
-- Name: suiza; Type: TABLE; Schema: OriginData; Owner: postgres
--

CREATE TABLE "OriginData".suiza (
    fid integer NOT NULL,
    geom public.geometry(MultiPolygonZ,4326),
    uuid character varying(38),
    datum_aend date,
    datum_erst date,
    erstell_j integer,
    erstell_m integer,
    revision_j integer,
    revision_m integer,
    grund_aend character varying(20),
    herkunft character varying(20),
    herkunft_j integer,
    herkunft_m integer,
    objektart character varying(50),
    revision_q character varying(20),
    bau_name_u character varying(38),
    name character varying(254),
    nutzung character varying(50)
);


ALTER TABLE "OriginData".suiza OWNER TO postgres;

--
-- TOC entry 243 (class 1259 OID 2758376)
-- Name: suiza_id_seq; Type: SEQUENCE; Schema: OriginData; Owner: postgres
--

CREATE SEQUENCE "OriginData".suiza_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "OriginData".suiza_id_seq OWNER TO postgres;

--
-- TOC entry 4348 (class 0 OID 0)
-- Dependencies: 243
-- Name: suiza_id_seq; Type: SEQUENCE OWNED BY; Schema: OriginData; Owner: postgres
--

ALTER SEQUENCE "OriginData".suiza_id_seq OWNED BY "OriginData".suiza.fid;


--
-- TOC entry 218 (class 1259 OID 2758176)
-- Name: POC001_Seville_1kmPopulation; Type: TABLE; Schema: Result; Owner: postgres
--

CREATE TABLE "Result"."POC001_Seville_1kmPopulation" (
    id bigint,
    id_process text,
    "localId" character varying(14) NOT NULL,
    id_popu text,
    "CurrentUse" character varying(18),
    geom public.geometry(MultiPolygon,4326),
    geom_pu public.geometry,
    population numeric,
    "popFootprint" numeric,
    "popVolumen" numeric,
    "popDwellings" numeric,
    "popResidentialArea" numeric,
    "Area" double precision,
    elevation numeric,
    "Volumen" double precision,
    "numberOfDwellings" integer,
    "ResidentialArea" integer,
    oid integer,
    namespace "char",
    "beginLifespanVersion" text,
    "endLifespanVersion" character varying(19),
    "conditionOfConstruction" character varying(10),
    "horizontalGeometryEstimatedAccuracy" double precision,
    "horizontalGeometryEstimatedAccuracy_uom" character varying(1),
    "horizontalGeometryReference" character varying(9),
    "referenceGeometry" boolean,
    "numberOfBuildingUnits" integer,
    "numberOfFloorsAboveGround" character varying
);


ALTER TABLE "Result"."POC001_Seville_1kmPopulation" OWNER TO postgres;

--
-- TOC entry 219 (class 1259 OID 2758181)
-- Name: POC002_Seville_250mPopulation; Type: TABLE; Schema: Result; Owner: postgres
--

CREATE TABLE "Result"."POC002_Seville_250mPopulation" (
    id bigint,
    id_process text,
    "localId" character varying(14),
    id_popu text,
    "CurrentUse" character varying(18),
    geom public.geometry(MultiPolygon,4326),
    geom_pu public.geometry,
    population numeric,
    "popFootprint" numeric,
    "popVolumen" numeric,
    "popDwellings" numeric,
    "popResidentialArea" numeric,
    "Area" double precision,
    elevation numeric,
    "Volumen" double precision,
    "numberOfDwellings" integer,
    "ResidentialArea" integer,
    oid integer,
    namespace text,
    "beginLifespanVersion" text,
    "endLifespanVersion" character varying(19),
    "conditionOfConstruction" character varying(10),
    "horizontalGeometryEstimatedAccuracy" double precision,
    "horizontalGeometryEstimatedAccuracy_uom" character varying(1),
    "horizontalGeometryReference" character varying(9),
    "referenceGeometry" boolean,
    "numberOfBuildingUnits" integer,
    "numberOfFloorsAboveGround" character varying
);


ALTER TABLE "Result"."POC002_Seville_250mPopulation" OWNER TO postgres;

--
-- TOC entry 220 (class 1259 OID 2758186)
-- Name: POC003_Seville_CensusPopulation; Type: TABLE; Schema: Result; Owner: postgres
--

CREATE TABLE "Result"."POC003_Seville_CensusPopulation" (
    id bigint,
    id_process text,
    "localId" character varying(14),
    id_popu text,
    "CurrentUse" character varying(18),
    geom public.geometry(Polygon,4326),
    geom_pu public.geometry,
    population numeric,
    "popFootprint" numeric,
    "popVolumen" numeric,
    "popDwellings" numeric,
    "popResidentialArea" numeric,
    "Area" double precision,
    elevation numeric,
    "Volumen" double precision,
    "numberOfDwellings" integer,
    "ResidentialArea" integer,
    oid integer,
    namespace text,
    "beginLifespanVersion" text,
    "endLifespanVersion" character varying(19),
    "conditionOfConstruction" character varying(10),
    "horizontalGeometryEstimatedAccuracy" double precision,
    "horizontalGeometryEstimatedAccuracy_uom" character varying(1),
    "horizontalGeometryReference" character varying(9),
    "referenceGeometry" boolean,
    "numberOfBuildingUnits" integer,
    "numberOfFloorsAboveGround" character varying
);


ALTER TABLE "Result"."POC003_Seville_CensusPopulation" OWNER TO postgres;

--
-- TOC entry 221 (class 1259 OID 2758191)
-- Name: POC004_France_1kmPopulation; Type: TABLE; Schema: Result; Owner: postgres
--

CREATE TABLE "Result"."POC004_France_1kmPopulation" (
    "localId" bigint,
    id_process text,
    id_popu character varying(254),
    "CurrentUse" character varying(21),
    population bigint,
    "popFootprint" double precision,
    "popVolumen" integer,
    "popDwellings" integer,
    "popResidentialArea" integer,
    "Area" double precision,
    "Height" integer,
    "Volumen" integer,
    "numberOfDwellings" integer,
    "ResidentialArea" integer,
    oid integer NOT NULL,
    geom public.geometry(MultiPolygon,4326),
    "inspireId" text,
    namespace text DEFAULT 'ES.SDGC.BU'::text,
    "LocalId" text
);


ALTER TABLE "Result"."POC004_France_1kmPopulation" OWNER TO postgres;

--
-- TOC entry 222 (class 1259 OID 2758197)
-- Name: POC005_LaPalma_250mPopulation; Type: TABLE; Schema: Result; Owner: postgres
--

CREATE TABLE "Result"."POC005_LaPalma_250mPopulation" (
    id bigint,
    id_process text,
    "localId" character varying(254),
    id_popu text,
    "CurrentUse" character varying(254),
    geom public.geometry(Polygon,4326),
    population numeric,
    "popFootprint" numeric,
    "popVolumen" numeric,
    "popDwellings" numeric,
    "popResidentialArea" numeric,
    "Area" double precision,
    "Volumen" double precision,
    "numberOfDwellings" bigint,
    "ResidentialArea" integer,
    oid integer,
    namespace text,
    "inspireId" text,
    "beginLifespanVersion" character varying(24),
    "endLifespanVersion" character varying(24),
    "conditionOfConstruction" character varying(254),
    "horizontalGeometryEstimatedAccuracy" numeric,
    "horizontalGeometryEstimatedAccuracy_uom" character varying(254),
    "horizontalGeometryReference" character varying(254),
    "referenceGeometry" integer,
    "numberOfBuildingUnits" bigint,
    "numberOfFloorsAboveGround" character varying(254)
);


ALTER TABLE "Result"."POC005_LaPalma_250mPopulation" OWNER TO postgres;

--
-- TOC entry 223 (class 1259 OID 2758202)
-- Name: POC006_FranSwiss; Type: TABLE; Schema: Result; Owner: postgres
--

CREATE TABLE "Result"."POC006_FranSwiss" (
    oid integer NOT NULL,
    geom public.geometry(PolygonZ,3035),
    id bigint,
    id_process character varying,
    id_buld integer,
    id_popu character varying,
    "CurrentUse" character varying,
    population double precision,
    "popFootprint" double precision,
    "popVolumen" double precision,
    "popDwellings" double precision,
    "popResidentialArea" double precision,
    "Area" double precision,
    elevation double precision,
    volumen integer,
    "numberOfDwellings" double precision,
    "ResidentialArea" double precision,
    "numberOfFloorsAboveGround" integer,
    "endLifespanVersion" character varying,
    "beginLifespanVersion" character varying,
    "localId" integer,
    namespace character varying,
    "conditionOfConstruction" character varying,
    "inspireId" integer,
    "referenceGeometry" integer,
    "numberOfBuildingUnits" integer,
    geom_pu character varying,
    id_unico integer
);


ALTER TABLE "Result"."POC006_FranSwiss" OWNER TO postgres;

--
-- TOC entry 224 (class 1259 OID 2758207)
-- Name: POC006_FranSwiss_oid_seq; Type: SEQUENCE; Schema: Result; Owner: postgres
--

CREATE SEQUENCE "Result"."POC006_FranSwiss_oid_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "Result"."POC006_FranSwiss_oid_seq" OWNER TO postgres;

--
-- TOC entry 4349 (class 0 OID 0)
-- Dependencies: 224
-- Name: POC006_FranSwiss_oid_seq; Type: SEQUENCE OWNED BY; Schema: Result; Owner: postgres
--

ALTER SEQUENCE "Result"."POC006_FranSwiss_oid_seq" OWNED BY "Result"."POC006_FranSwiss".oid;


--
-- TOC entry 225 (class 1259 OID 2758233)
-- Name: results_metadata; Type: TABLE; Schema: Result; Owner: postgres
--

CREATE TABLE "Result".results_metadata (
    id integer NOT NULL,
    metadato json
);


ALTER TABLE "Result".results_metadata OWNER TO postgres;

--
-- TOC entry 226 (class 1259 OID 2758238)
-- Name: metadatos_resultados_id_seq; Type: SEQUENCE; Schema: Result; Owner: postgres
--

CREATE SEQUENCE "Result".metadatos_resultados_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "Result".metadatos_resultados_id_seq OWNER TO postgres;

--
-- TOC entry 4350 (class 0 OID 0)
-- Dependencies: 226
-- Name: metadatos_resultados_id_seq; Type: SEQUENCE OWNED BY; Schema: Result; Owner: postgres
--

ALTER SEQUENCE "Result".metadatos_resultados_id_seq OWNED BY "Result".results_metadata.id;


--
-- TOC entry 227 (class 1259 OID 2758244)
-- Name: results04_bulding_af1cb4a3_4694_4a82_853d_4f731b4e8647_oid_seq; Type: SEQUENCE; Schema: Result; Owner: postgres
--

CREATE SEQUENCE "Result".results04_bulding_af1cb4a3_4694_4a82_853d_4f731b4e8647_oid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "Result".results04_bulding_af1cb4a3_4694_4a82_853d_4f731b4e8647_oid_seq OWNER TO postgres;

--
-- TOC entry 4351 (class 0 OID 0)
-- Dependencies: 227
-- Name: results04_bulding_af1cb4a3_4694_4a82_853d_4f731b4e8647_oid_seq; Type: SEQUENCE OWNED BY; Schema: Result; Owner: postgres
--

ALTER SEQUENCE "Result".results04_bulding_af1cb4a3_4694_4a82_853d_4f731b4e8647_oid_seq OWNED BY "Result"."POC004_France_1kmPopulation".oid;


--
-- TOC entry 4110 (class 2604 OID 2758377)
-- Name: Countries id; Type: DEFAULT; Schema: OriginData; Owner: postgres
--

ALTER TABLE ONLY "OriginData"."Countries" ALTER COLUMN id SET DEFAULT nextval('"OriginData"."Countries_id_seq"'::regclass);


--
-- TOC entry 4111 (class 2604 OID 2758378)
-- Name: JRC_POPULATION_2018 id; Type: DEFAULT; Schema: OriginData; Owner: postgres
--

ALTER TABLE ONLY "OriginData"."JRC_POPULATION_2018" ALTER COLUMN id SET DEFAULT nextval('"OriginData"."JRC_POPULATION_2018_id_seq"'::regclass);


--
-- TOC entry 4112 (class 2604 OID 2758382)
-- Name: edificios_la_palma id; Type: DEFAULT; Schema: OriginData; Owner: postgres
--

ALTER TABLE ONLY "OriginData".edificios_la_palma ALTER COLUMN id SET DEFAULT nextval('"OriginData".edificios_la_palma_id_seq'::regclass);


--
-- TOC entry 4113 (class 2604 OID 2758383)
-- Name: fr_edificios id; Type: DEFAULT; Schema: OriginData; Owner: postgres
--

ALTER TABLE ONLY "OriginData".fr_edificios ALTER COLUMN id SET DEFAULT nextval('"OriginData".fr_edificios_id_seq'::regclass);


--
-- TOC entry 4114 (class 2604 OID 2758385)
-- Name: palma_pob id; Type: DEFAULT; Schema: OriginData; Owner: postgres
--

ALTER TABLE ONLY "OriginData".palma_pob ALTER COLUMN id SET DEFAULT nextval('"OriginData".palma_pob_id_seq'::regclass);


--
-- TOC entry 4115 (class 2604 OID 2758387)
-- Name: perimetros_coladas id; Type: DEFAULT; Schema: OriginData; Owner: postgres
--

ALTER TABLE ONLY "OriginData".perimetros_coladas ALTER COLUMN id SET DEFAULT nextval('"OriginData".perimetros_coladas_id_seq'::regclass);


--
-- TOC entry 4116 (class 2604 OID 2758388)
-- Name: suiza fid; Type: DEFAULT; Schema: OriginData; Owner: postgres
--

ALTER TABLE ONLY "OriginData".suiza ALTER COLUMN fid SET DEFAULT nextval('"OriginData".suiza_id_seq'::regclass);


--
-- TOC entry 4107 (class 2604 OID 2758245)
-- Name: POC004_France_1kmPopulation oid; Type: DEFAULT; Schema: Result; Owner: postgres
--

ALTER TABLE ONLY "Result"."POC004_France_1kmPopulation" ALTER COLUMN oid SET DEFAULT nextval('"Result".results04_bulding_af1cb4a3_4694_4a82_853d_4f731b4e8647_oid_seq'::regclass);


--
-- TOC entry 4108 (class 2604 OID 2758246)
-- Name: POC006_FranSwiss oid; Type: DEFAULT; Schema: Result; Owner: postgres
--

ALTER TABLE ONLY "Result"."POC006_FranSwiss" ALTER COLUMN oid SET DEFAULT nextval('"Result"."POC006_FranSwiss_oid_seq"'::regclass);


--
-- TOC entry 4109 (class 2604 OID 2758247)
-- Name: results_metadata id; Type: DEFAULT; Schema: Result; Owner: postgres
--

ALTER TABLE ONLY "Result".results_metadata ALTER COLUMN id SET DEFAULT nextval('"Result".metadatos_resultados_id_seq'::regclass);


--
-- TOC entry 4314 (class 0 OID 2758280)
-- Dependencies: 228
-- Data for Name: Countries; Type: TABLE DATA; Schema: OriginData; Owner: postgres
--



--
-- TOC entry 4316 (class 0 OID 2758286)
-- Dependencies: 230
-- Data for Name: JRC_POPULATION_2018; Type: TABLE DATA; Schema: OriginData; Owner: postgres
--



--
-- TOC entry 4318 (class 0 OID 2758303)
-- Dependencies: 232
-- Data for Name: building_seville; Type: TABLE DATA; Schema: OriginData; Owner: postgres
--



--
-- TOC entry 4319 (class 0 OID 2758320)
-- Dependencies: 233
-- Data for Name: edificios_la_palma; Type: TABLE DATA; Schema: OriginData; Owner: postgres
--



--
-- TOC entry 4321 (class 0 OID 2758326)
-- Dependencies: 235
-- Data for Name: fr_edificios; Type: TABLE DATA; Schema: OriginData; Owner: postgres
--



--
-- TOC entry 4323 (class 0 OID 2758343)
-- Dependencies: 237
-- Data for Name: palma_pob; Type: TABLE DATA; Schema: OriginData; Owner: postgres
--



--
-- TOC entry 4325 (class 0 OID 2758355)
-- Dependencies: 239
-- Data for Name: perimetros_coladas; Type: TABLE DATA; Schema: OriginData; Owner: postgres
--



--
-- TOC entry 4327 (class 0 OID 2758361)
-- Dependencies: 241
-- Data for Name: pob_palma_afectada; Type: TABLE DATA; Schema: OriginData; Owner: postgres
--



--
-- TOC entry 4328 (class 0 OID 2758371)
-- Dependencies: 242
-- Data for Name: suiza; Type: TABLE DATA; Schema: OriginData; Owner: postgres
--



--
-- TOC entry 4304 (class 0 OID 2758176)
-- Dependencies: 218
-- Data for Name: POC001_Seville_1kmPopulation; Type: TABLE DATA; Schema: Result; Owner: postgres
--



--
-- TOC entry 4305 (class 0 OID 2758181)
-- Dependencies: 219
-- Data for Name: POC002_Seville_250mPopulation; Type: TABLE DATA; Schema: Result; Owner: postgres
--



--
-- TOC entry 4306 (class 0 OID 2758186)
-- Dependencies: 220
-- Data for Name: POC003_Seville_CensusPopulation; Type: TABLE DATA; Schema: Result; Owner: postgres
--



--
-- TOC entry 4307 (class 0 OID 2758191)
-- Dependencies: 221
-- Data for Name: POC004_France_1kmPopulation; Type: TABLE DATA; Schema: Result; Owner: postgres
--



--
-- TOC entry 4308 (class 0 OID 2758197)
-- Dependencies: 222
-- Data for Name: POC005_LaPalma_250mPopulation; Type: TABLE DATA; Schema: Result; Owner: postgres
--



--
-- TOC entry 4309 (class 0 OID 2758202)
-- Dependencies: 223
-- Data for Name: POC006_FranSwiss; Type: TABLE DATA; Schema: Result; Owner: postgres
--



--
-- TOC entry 4311 (class 0 OID 2758233)
-- Dependencies: 225
-- Data for Name: results_metadata; Type: TABLE DATA; Schema: Result; Owner: postgres
--



--
-- TOC entry 4104 (class 0 OID 2757451)
-- Dependencies: 214
-- Data for Name: spatial_ref_sys; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- TOC entry 4352 (class 0 OID 0)
-- Dependencies: 229
-- Name: Countries_id_seq; Type: SEQUENCE SET; Schema: OriginData; Owner: postgres
--

SELECT pg_catalog.setval('"OriginData"."Countries_id_seq"', 1, false);


--
-- TOC entry 4353 (class 0 OID 0)
-- Dependencies: 231
-- Name: JRC_POPULATION_2018_id_seq; Type: SEQUENCE SET; Schema: OriginData; Owner: postgres
--

SELECT pg_catalog.setval('"OriginData"."JRC_POPULATION_2018_id_seq"', 1, false);


--
-- TOC entry 4354 (class 0 OID 0)
-- Dependencies: 234
-- Name: edificios_la_palma_id_seq; Type: SEQUENCE SET; Schema: OriginData; Owner: postgres
--

SELECT pg_catalog.setval('"OriginData".edificios_la_palma_id_seq', 1, false);


--
-- TOC entry 4355 (class 0 OID 0)
-- Dependencies: 236
-- Name: fr_edificios_id_seq; Type: SEQUENCE SET; Schema: OriginData; Owner: postgres
--

SELECT pg_catalog.setval('"OriginData".fr_edificios_id_seq', 1, false);


--
-- TOC entry 4356 (class 0 OID 0)
-- Dependencies: 238
-- Name: palma_pob_id_seq; Type: SEQUENCE SET; Schema: OriginData; Owner: postgres
--

SELECT pg_catalog.setval('"OriginData".palma_pob_id_seq', 1, false);


--
-- TOC entry 4357 (class 0 OID 0)
-- Dependencies: 240
-- Name: perimetros_coladas_id_seq; Type: SEQUENCE SET; Schema: OriginData; Owner: postgres
--

SELECT pg_catalog.setval('"OriginData".perimetros_coladas_id_seq', 1, false);


--
-- TOC entry 4358 (class 0 OID 0)
-- Dependencies: 243
-- Name: suiza_id_seq; Type: SEQUENCE SET; Schema: OriginData; Owner: postgres
--

SELECT pg_catalog.setval('"OriginData".suiza_id_seq', 1, false);


--
-- TOC entry 4359 (class 0 OID 0)
-- Dependencies: 224
-- Name: POC006_FranSwiss_oid_seq; Type: SEQUENCE SET; Schema: Result; Owner: postgres
--

SELECT pg_catalog.setval('"Result"."POC006_FranSwiss_oid_seq"', 1, false);


--
-- TOC entry 4360 (class 0 OID 0)
-- Dependencies: 226
-- Name: metadatos_resultados_id_seq; Type: SEQUENCE SET; Schema: Result; Owner: postgres
--

SELECT pg_catalog.setval('"Result".metadatos_resultados_id_seq', 1, false);


--
-- TOC entry 4361 (class 0 OID 0)
-- Dependencies: 227
-- Name: results04_bulding_af1cb4a3_4694_4a82_853d_4f731b4e8647_oid_seq; Type: SEQUENCE SET; Schema: Result; Owner: postgres
--

SELECT pg_catalog.setval('"Result".results04_bulding_af1cb4a3_4694_4a82_853d_4f731b4e8647_oid_seq', 1, false);


--
-- TOC entry 4134 (class 2606 OID 2758390)
-- Name: Countries Countries_pkey; Type: CONSTRAINT; Schema: OriginData; Owner: postgres
--

ALTER TABLE ONLY "OriginData"."Countries"
    ADD CONSTRAINT "Countries_pkey" PRIMARY KEY (id);


--
-- TOC entry 4137 (class 2606 OID 2758394)
-- Name: JRC_POPULATION_2018 JRC_POPULATION_2018_pkey; Type: CONSTRAINT; Schema: OriginData; Owner: postgres
--

ALTER TABLE ONLY "OriginData"."JRC_POPULATION_2018"
    ADD CONSTRAINT "JRC_POPULATION_2018_pkey" PRIMARY KEY (id);


--
-- TOC entry 4140 (class 2606 OID 2758398)
-- Name: building_seville building_pkey; Type: CONSTRAINT; Schema: OriginData; Owner: postgres
--

ALTER TABLE ONLY "OriginData".building_seville
    ADD CONSTRAINT building_pkey PRIMARY KEY (id);


--
-- TOC entry 4143 (class 2606 OID 2758404)
-- Name: edificios_la_palma edificios_la_palma_pkey; Type: CONSTRAINT; Schema: OriginData; Owner: postgres
--

ALTER TABLE ONLY "OriginData".edificios_la_palma
    ADD CONSTRAINT edificios_la_palma_pkey PRIMARY KEY (id);


--
-- TOC entry 4146 (class 2606 OID 2758408)
-- Name: fr_edificios fr_edificios_pkey; Type: CONSTRAINT; Schema: OriginData; Owner: postgres
--

ALTER TABLE ONLY "OriginData".fr_edificios
    ADD CONSTRAINT fr_edificios_pkey PRIMARY KEY (id);


--
-- TOC entry 4149 (class 2606 OID 2758412)
-- Name: palma_pob palma_pob_pkey; Type: CONSTRAINT; Schema: OriginData; Owner: postgres
--

ALTER TABLE ONLY "OriginData".palma_pob
    ADD CONSTRAINT palma_pob_pkey PRIMARY KEY (id);


--
-- TOC entry 4152 (class 2606 OID 2758416)
-- Name: perimetros_coladas perimetros_coladas_pkey; Type: CONSTRAINT; Schema: OriginData; Owner: postgres
--

ALTER TABLE ONLY "OriginData".perimetros_coladas
    ADD CONSTRAINT perimetros_coladas_pkey PRIMARY KEY (id);


--
-- TOC entry 4155 (class 2606 OID 2758418)
-- Name: pob_palma_afectada pob_palma_afectada_pkey; Type: CONSTRAINT; Schema: OriginData; Owner: postgres
--

ALTER TABLE ONLY "OriginData".pob_palma_afectada
    ADD CONSTRAINT pob_palma_afectada_pkey PRIMARY KEY (id);


--
-- TOC entry 4159 (class 2606 OID 2758422)
-- Name: suiza suiza_pkey; Type: CONSTRAINT; Schema: OriginData; Owner: postgres
--

ALTER TABLE ONLY "OriginData".suiza
    ADD CONSTRAINT suiza_pkey PRIMARY KEY (fid);


--
-- TOC entry 4120 (class 2606 OID 2758249)
-- Name: POC001_Seville_1kmPopulation POC001_Seville_1kmPopulation_pkey; Type: CONSTRAINT; Schema: Result; Owner: postgres
--

ALTER TABLE ONLY "Result"."POC001_Seville_1kmPopulation"
    ADD CONSTRAINT "POC001_Seville_1kmPopulation_pkey" PRIMARY KEY ("localId");


--
-- TOC entry 4129 (class 2606 OID 2758251)
-- Name: POC006_FranSwiss POC006_FranSwiss_pkey; Type: CONSTRAINT; Schema: Result; Owner: postgres
--

ALTER TABLE ONLY "Result"."POC006_FranSwiss"
    ADD CONSTRAINT "POC006_FranSwiss_pkey" PRIMARY KEY (oid);


--
-- TOC entry 4132 (class 2606 OID 2758253)
-- Name: results_metadata metadatos_resultados_pkey; Type: CONSTRAINT; Schema: Result; Owner: postgres
--

ALTER TABLE ONLY "Result".results_metadata
    ADD CONSTRAINT metadatos_resultados_pkey PRIMARY KEY (id);


--
-- TOC entry 4126 (class 2606 OID 2758255)
-- Name: POC004_France_1kmPopulation results04_bulding_af1cb4a3_4694_4a82_853d_4f731b4e8647_pkey; Type: CONSTRAINT; Schema: Result; Owner: postgres
--

ALTER TABLE ONLY "Result"."POC004_France_1kmPopulation"
    ADD CONSTRAINT results04_bulding_af1cb4a3_4694_4a82_853d_4f731b4e8647_pkey PRIMARY KEY (oid);


--
-- TOC entry 4135 (class 1259 OID 2758423)
-- Name: sidx_Countries_geom; Type: INDEX; Schema: OriginData; Owner: postgres
--

CREATE INDEX "sidx_Countries_geom" ON "OriginData"."Countries" USING gist (geom);


--
-- TOC entry 4138 (class 1259 OID 2758425)
-- Name: sidx_JRC_POPULATION_2018_geom; Type: INDEX; Schema: OriginData; Owner: postgres
--

CREATE INDEX "sidx_JRC_POPULATION_2018_geom" ON "OriginData"."JRC_POPULATION_2018" USING gist (geom);


--
-- TOC entry 4141 (class 1259 OID 2758427)
-- Name: sidx_building_geom; Type: INDEX; Schema: OriginData; Owner: postgres
--

CREATE INDEX sidx_building_geom ON "OriginData".building_seville USING gist (geom);


--
-- TOC entry 4144 (class 1259 OID 2758430)
-- Name: sidx_edificios_la_palma_geom; Type: INDEX; Schema: OriginData; Owner: postgres
--

CREATE INDEX sidx_edificios_la_palma_geom ON "OriginData".edificios_la_palma USING gist (geom);


--
-- TOC entry 4147 (class 1259 OID 2758432)
-- Name: sidx_fr_edificios_geom; Type: INDEX; Schema: OriginData; Owner: postgres
--

CREATE INDEX sidx_fr_edificios_geom ON "OriginData".fr_edificios USING gist (geom);


--
-- TOC entry 4150 (class 1259 OID 2758434)
-- Name: sidx_palma_pob_geom; Type: INDEX; Schema: OriginData; Owner: postgres
--

CREATE INDEX sidx_palma_pob_geom ON "OriginData".palma_pob USING gist (geom);


--
-- TOC entry 4153 (class 1259 OID 2758436)
-- Name: sidx_perimetros_coladas_geom; Type: INDEX; Schema: OriginData; Owner: postgres
--

CREATE INDEX sidx_perimetros_coladas_geom ON "OriginData".perimetros_coladas USING gist (geom);


--
-- TOC entry 4156 (class 1259 OID 2758437)
-- Name: sidx_pob_palma_afectada_geom; Type: INDEX; Schema: OriginData; Owner: postgres
--

CREATE INDEX sidx_pob_palma_afectada_geom ON "OriginData".pob_palma_afectada USING gist (geom);


--
-- TOC entry 4157 (class 1259 OID 2758439)
-- Name: sidx_suiza_geom; Type: INDEX; Schema: OriginData; Owner: postgres
--

CREATE INDEX sidx_suiza_geom ON "OriginData".suiza USING gist (geom);


--
-- TOC entry 4121 (class 1259 OID 2758256)
-- Name: fr_geom_idx; Type: INDEX; Schema: Result; Owner: postgres
--

CREATE INDEX fr_geom_idx ON "Result"."POC001_Seville_1kmPopulation" USING gist (geom);


--
-- TOC entry 4124 (class 1259 OID 2758257)
-- Name: fr_geom_idx0; Type: INDEX; Schema: Result; Owner: postgres
--

CREATE INDEX fr_geom_idx0 ON "Result"."POC004_France_1kmPopulation" USING gist (geom);


--
-- TOC entry 4122 (class 1259 OID 2758258)
-- Name: fr_geom_idx_poc002; Type: INDEX; Schema: Result; Owner: postgres
--

CREATE INDEX fr_geom_idx_poc002 ON "Result"."POC002_Seville_250mPopulation" USING gist (geom);


--
-- TOC entry 4123 (class 1259 OID 2758259)
-- Name: fr_geom_idx_poc003; Type: INDEX; Schema: Result; Owner: postgres
--

CREATE INDEX fr_geom_idx_poc003 ON "Result"."POC003_Seville_CensusPopulation" USING gist (geom);


--
-- TOC entry 4127 (class 1259 OID 2758260)
-- Name: fr_geom_idx_poc005; Type: INDEX; Schema: Result; Owner: postgres
--

CREATE INDEX fr_geom_idx_poc005 ON "Result"."POC005_LaPalma_250mPopulation" USING gist (geom);


--
-- TOC entry 4130 (class 1259 OID 2758261)
-- Name: sidx_POC006_FranSwiss_geom; Type: INDEX; Schema: Result; Owner: postgres
--

CREATE INDEX "sidx_POC006_FranSwiss_geom" ON "Result"."POC006_FranSwiss" USING gist (geom);


-- Completed on 2022-12-15 08:27:11

--
-- PostgreSQL database dump complete
--


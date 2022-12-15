### POPIMPACT FUNCTIONS AT GO-PEG´S PROJECT
## #METADATA

- **Web:** https://www.go-peg.eu/
- **Autor:** Geograma
- **Contact:** go-peg@geograma.com
- **Version:** 1.0
- **Date:** 2022-03-01 09:52:16
- **Dumped** from database version 14.0


## #CODE
<details>
  <summary>
PopImpact's postGIS functions that normalise the building information to the inspiration model and assign the population using different disaggregation methods: area, volume, number of dwellings and/or residential area.


<code>&lt;CODE&gt;</code> (<i>click to expand</i>)</summary>
  <!-- have to be followed by an empty line! -->

## *PopImpact´s Function* 

```sql
DROP DATABASE "goPEC_BULDING"; 
CREATE DATABASE "goPEC_BULDING" WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE = 'Spanish_Spain.1252'; 
ALTER DATABASE "goPEC_BULDING" OWNER TO postgres;


CREATE SCHEMA "POPIMPACT";
ALTER SCHEMA "POPIMPACT" OWNER TO postgres;

CREATE DOMAIN "POPIMPACT".typeheight AS text
	CONSTRAINT tipo_volumen_check CHECK (((VALUE = 'Floor'::text) OR (VALUE = 'Height'::text)));


ALTER DOMAIN "POPIMPACT".typeheight OWNER TO postgres;


/*Function that is responsible for assig the population to building
JSON EXAMPLE:
('{"Process":{"IdProcess":"124a9cad-6d21-4037-a362-f41821d35054","MetodFootprint":"True","MetodVolumen":"True","MetodDWellings":"True","MetodResidencialArea":"False","UseFilter":"True","epsg":3035,"BuildingFilter":"False"},"BuildingData":{"Id":1,"SchemaName":"bulding_pop","TableName":"building","IdData":"localId","epsg":25830,"geometry":"geom","useField":"currentUse","useValue":"1_residential","area":"True","area_calculate":"True","area_field":"","volumen":"True","volumen_calculate":"True","volumen_type":"Floor","volumen_field":"numberOfFloorsAboveGround","Dwellings":"True","Dwellings_field":"numberOfDwellings","residential_area":"False","residential_area_field":""},"PopulationData":{"Id":2,"SchemaName":"bulding_pop","TableName":"JRC_POPULATION_2018","Id":"grd_id","epsg":3035,"geometry":"geom","PopulationField":"tot_p_2018"}}'::json);
*/

CREATE FUNCTION "POPIMPACT"."_DisaggregatePopulationBuildings"(json) RETURNS void
    LANGUAGE plpgsql
    AS $_$
 
	DECLARE
	-- PARSER JSON
		json_in json;
		uuid text;
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
		IdPopulation:=(json_in->'PopulationData'->>'IdData')::text;
		PopulationData:=(json_in->'PopulationData'->>'PopulationField')::text;		
	  	use_value:=(json_in->'BuildingData'->>'useValue')::text;
	  	MetodFootprint:=(json_in->'Process'->>'MetodFootprint')::boolean;
		MetodVolumen:=(json_in->'Process'->>'MetodVolumen')::boolean;
		MetodDWellings:=(json_in->'Process'->>'MetodDWellings')::boolean;
		MetodResidencialArea:=(json_in->'Process'->>'MetodResidencialArea')::boolean;
	  	UseFilter:=(json_in->'Process'->>'UseFilter')::boolean;
		 
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
					sql_query:='SELECT  count(edif.area) as cuenta_edificios,
								sum(edif.area) AS suma_edif_area,
								sum(edif.volumen) as suma_edif_volumen,
								sum(edif.viviendas) as suma_edif_viviendas ,
								sum(edif.sup_residencial) as suma_sup_residencial 
								FROM   resultados.resultado_edificios_'||uuid||'  as edif ,"'||SchemaPopulation||'"."'||TablePopulation||'" AS pob ';
								--SIN FILTRO DE USO
								sql_query_without_filter:= sql_query||' WHERE "'||IdPopulation||'" ='''||CurrentIdPopulation||''' 
								and ('||GeometryPopulation||' && edif.geom_pu) and st_intersects('||GeometryPopulation||' ,edif.geom_pu) ' ;
								--CON FILTRO DE USO		
								 sql_query_with_filter:=sql_query ||' WHERE "'||IdPopulation||'" ='''||CurrentIdPopulation||''' and uso='''||use_value||''' 
								 and ('||GeometryPopulation||' && edif.geom_pu)and st_intersects('||GeometryPopulation||' ,edif.geom_pu) ' ;	 
			     
				 -- SQL SELECT BUILDING
					  sql_base:='SELECT Id_edif, area,volumen, viviendas, sup_residencial,edif.geom  FROM resultados.resultado_edificios_'|| uuid||'  as edif,
							     "'||SchemaPopulation||'"."'||TablePopulation||'" AS pob';					 	

			    -- CHECK USE FILTER
					IF UseFilter IS true THEN				
							EXECUTE sql_query_with_filter INTO record_sum_buil;  		
 							 sql_query:= sql_base||' WHERE (edif.uso='''||use_value||''') and (pob."'||IdPopulation||'" ='''||CurrentIdPopulation||''' ) 
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
					
					BuildingArea:=COALESCE(record_building.area, 0);  
					BuildingVolumen:=COALESCE(record_building.volumen, 0);
					BuildingDwellings:=COALESCE(record_building.viviendas, 0);					
					BuildingResidencialArea:=COALESCE(record_building.sup_residencial, 0);
					 

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
 
							 
								sql_query:= 'UPDATE resultados.resultado_edificios_'||uuid||' 
								                 SET Population='||Population||',
											     id_pobl='''||CurrentIdPopulation||''', 
												 "PopFootprint"='||PopFootprint||' , 
												"PopVolumen"='||PopVolumen||' , 
												"PopDwellings"='||PopDwellings||' , 
												"PopResidencialArea"='||PopResidencialArea||' 							
												 WHERE id_edif='''||record_building.Id_edif||''' ;';				
 
								EXECUTE sql_query; 
 			  END LOOP;
			  close cursor_building;		
	END LOOP;
	close cursor_pob;
	 
        --METADATA
		ProcessTime:= clock_timestamp()- ProcessTime;
		sql_query:= 'SELECT COUNT(*)  FROM  "'||SchemaPopulation||'"."'||TablePopulation||'" 
						WHERE  "'||PopulationData||'" IS NULL OR  "'||PopulationData||'"=0';		
 
		EXECUTE sql_query INTO NZonaPopWithoutPop;	
 
 	  		sql_query:='SELECT SUM(pob_total) as pob_total  FROM (SELECT DISTINCT pob."'||PopulationData||'" as  pob_total 
			               FROM "'||SchemaPopulation||'"."'||TablePopulation||'" as pob, 
						   resultados.resultado_edificios_'||uuid||' as edif
						    WHERE '||GeometryPopulation||'&& '||GeometryBuildingPU||' 
							and st_intersects('||GeometryPopulation||' ,'||GeometryBuildingPU||')) as a';				  
			 EXECUTE sql_query INTO TotalPopulation; 

			--QUALITY FOOTPRINT			 
			 Footprint_NBuildingWithPop:=0;
			 Footprint_NBuildingWithoutPop:=0;
			 Footprint_NBuildingMore100Pop:=0;
			 FootprintPopFinal:=0;		 
 			    sql_query:='SELECT bulding_pop."_Metadatos_NBuildingWithPop"('''||uuid||''',''PopFootprint''::text,'||UseFilter||','''||use_value||''')';
			  	EXECUTE  sql_query INTO Footprint_NBuildingWithPop;
				sql_query:='SELECT bulding_pop."_Metadatos_NBuildingWithoutPop"('''||uuid||''',''PopFootprint''::text,'||UseFilter||','''||use_value||''')';
				EXECUTE  sql_query INTO  Footprint_NBuildingWithoutPop;
				sql_query:='SELECT bulding_pop."_Metadatos_NBuildingMore100Pop"('''||uuid||''', ''PopFootprint''::text)';
				EXECUTE  sql_query INTO 	Footprint_NBuildingMore100Pop;				
				sql_query:='SELECT  bulding_pop."_Metadatos_Poblacionactual"('''||uuid||''', ''PopFootprint''::text)';
				EXECUTE  sql_query INTO CurrentPopFootprint; 
				FootprintPopFinal:= TotalPopulation-CurrentPopFootprint;
				
	        --QUALITY VOLUMEN	
			 Volumen_NBuildingWithPop:=0;
			 Volumen_NBuildingWithoutPop:=0;
			 Volumen_NBuildingMore100Pop:=0;
			 VolumenPopFinal:=0;			 
  			    sql_query:='SELECT bulding_pop."_Metadatos_NBuildingWithPop"('''||uuid||''',''PopVolumen''::text,'||UseFilter||','''||use_value||''')';
			  	EXECUTE  sql_query INTO Volumen_NBuildingWithPop;
				sql_query:='SELECT bulding_pop."_Metadatos_NBuildingWithoutPop"('''||uuid||''',''PopVolumen''::text,'||UseFilter||','''||use_value||''')';
				EXECUTE  sql_query INTO  Volumen_NBuildingWithoutPop;
				sql_query:='SELECT  bulding_pop."_Metadatos_NBuildingMore100Pop"('''||uuid||''', ''PopVolumen''::text) ';
				EXECUTE  sql_query INTO Volumen_NBuildingMore100Pop;
				sql_query:='SELECT  bulding_pop."_Metadatos_Poblacionactual"('''||uuid||''', ''PopVolumen''::text) ';
				EXECUTE  sql_query INTO CurrentPopVolumen;  
				VolumenPopFinal:= TotalPopulation-CurrentPopVolumen;			
			 
			--QUALITY WELLING	
 			 Dwellings_NBuildingWithPop:=0;
			 Dwellings_NBuildingWithoutPop:=0;
			 Dwellings_NBuildingMore100Pop:=0;
			 DwellingsPopFinal:=0;
			    sql_query:='SELECT bulding_pop."_Metadatos_NBuildingWithPop"('''||uuid||''',''PopDwellings''::text,'||UseFilter||','''||use_value||''')'; 
			  	EXECUTE  sql_query INTO Dwellings_NBuildingWithPop;
				sql_query:='SELECT bulding_pop."_Metadatos_NBuildingWithoutPop"('''||uuid||''',''PopDwellings''::text,'||UseFilter||','''||use_value||''')';
				EXECUTE  sql_query INTO  Dwellings_NBuildingWithoutPop;			  
				sql_query:='SELECT bulding_pop."_Metadatos_NBuildingMore100Pop"('''||uuid||''',''PopDwellings''::text) ';
				EXECUTE  sql_query   INTO Dwellings_NBuildingMore100Pop;
				sql_query:='SELECT  bulding_pop."_Metadatos_Poblacionactual"('''||uuid||''',''PopDwellings''::text) ';
				EXECUTE  sql_query INTO  CurrentPopDwellings;  
				DwellingsPopFinal:= TotalPopulation-CurrentPopDwellings;
 
			--QUALITY RESIDENTIAL	
		 	 ResidencialArea_NBuildingWithPop:=0;
			 ResidencialArea_NBuildingWithoutPop:=0;
			 ResidencialArea_NBuildingMore100Pop:=0;
			 ResidencialAreaPopFinal:=0;	
			    sql_query:='SELECT bulding_pop."_Metadatos_NBuildingWithPop"('''||uuid||''',''PopResidencialArea''::text,'||UseFilter||','''||use_value||''')'; 
			  	EXECUTE  sql_query INTO ResidencialArea_NBuildingWithPop;
				sql_query:='SELECT bulding_pop."_Metadatos_NBuildingWithoutPop"('''||uuid||''',''PopResidencialArea''::text,'||UseFilter||','''||use_value||''')';
				EXECUTE  sql_query INTO  ResidencialArea_NBuildingWithoutPop; 		 		  
				sql_query:='SELECT  bulding_pop."_Metadatos_NBuildingMore100Pop"('''||uuid||''',''PopResidencialArea''::text)';				
				EXECUTE  sql_query INTO ResidencialArea_NBuildingMore100Pop;
				sql_query:='SELECT  bulding_pop."_Metadatos_Poblacionactual"('''||uuid||''',''PopResidencialArea''::text)';				
				EXECUTE  sql_query INTO  CurrentPopResidencialArea;  
				ResidencialAreaPopFinal:= TotalPopulation-CurrentPopResidencialArea;
 				
			 --FILTER BUILDINGS
				sql_query_metadata:='SELECT count(*) as cuenta_edificios FROM  resultados.resultado_edificios_'||uuid||' as edif WHERE "uso"='''||use_value||'''';
 				EXECUTE sql_query_metadata INTO NBuildingFilter;
				
				sql_query_metadata:='SELECT count(*) as cuenta_edificios FROM  resultados.resultado_edificios_'||uuid||' as edif WHERE uso!='''||use_value||''' OR uso is null';
 				EXECUTE sql_query_metadata INTO NBuildingWithoutFilter; 
				
			metadate_json:='{"Proceso":{"IdProceso":"'||(json_in->'Proceso'->>'IdProceso')||'","FechaProceso":"'||now()||'","ProcessTime":"'||ProcessTime||'","EPSG": '||EPSGProyect||',"MetodoHuella":"'||MetodFootprint||'","MetodoVolumen":"'||MetodVolumen||'","MetodoNViviendas":"'||MetodDWellings||'","MetodoSupResidencial":"'||MetodResidencialArea||'","Ambit":"'||Ambit||'","epsg":'||EPSGProyect||'},"DatoOrigen":[{"IdDatoOrigen":"'||IdBuilding||'","NombreDatoOrigen":"'||TableBuilding||'","epsg":'||EPSGBuilding||'},{"IdDatoOrigen":"'||IdPopulation||'","NombreDatoOrigen":"'||TablePopulation||'","epsg":'||EPSGPopulation||'}],"linaje":[{"paso":1,"nombre":"Pasar a puntos la capa de edificios y armonizar los nombre de los atributos y epsg"},{"paso":2,"nombre":"Se intersecta los edificios puntuales( centro de gravedad) con los recintos de Population y se n_count la Population total, area, volumen, sup. residencia y número totales de edicios"},{"paso":3,"nombre":"Se recorren los edificos de cada zona de población y se asigna la población de los métodos selcionados, al último registro se le asigna los valores de resto" }],"Calidad":{"NBuilding":'||NBuilding||',"NPopArea":'||NPopArea||', "NZonaPopWithoutPop":'||NZonaPopWithoutPop||',"NBuildingFilter":'||NBuildingFilter||',"NBuildingWithoutFilter":'||NBuildingWithoutFilter||',"TotalPopulation":'||TotalPopulation||'},"CalidadMetodoHuella":{"NEdificiosConPob":'||Footprint_NBuildingWithPop||',"NEdificiosSinPob":'||Footprint_NBuildingWithoutPop||',"NBuildingMore100Pop":'||Footprint_NBuildingMore100Pop||',"PobNoAsignada":'||FootprintPopFinal||'},"CalidadMetodoVolumen":{"NEdificiosConPob":'||Volumen_NBuildingWithPop||',"NEdificiosSinPob":'||Volumen_NBuildingWithoutPop||',"NBuildingMore100Pop":'||Volumen_NBuildingMore100Pop||',"PobNoAsignada":'||VolumenPopFinal||'},"CalidadMetodoNViviendas":{"NEdificiosConPob":'||Dwellings_NBuildingWithPop||',"NEdificiosSinPob":'||Dwellings_NBuildingWithoutPop||',"NBuildingMore100Pop":'||Dwellings_NBuildingMore100Pop||',"PobNoAsignada":'||DwellingsPopFinal||'},"CalidadMetodoSupResidencial":{"NEdificiosConPob":'||ResidencialArea_NBuildingWithPop||',"NEdificiosSinPob":'||ResidencialArea_NBuildingWithoutPop||',"NBuildingMore100Pop":'||ResidencialArea_NBuildingMore100Pop||',"PobNoAsignada":'||ResidencialAreaPopFinal||'}}';
			sql_query:= 'INSERT INTO resultados.resultados_metadatos( metadato)VALUES ('''||metadate_json||''');';				
			EXECUTE sql_query; 
 	END;	

$_$;

COMMENT ON FUNCTION "POPIMPACT"."_DisaggregatePopulationBuildings"(json) IS 'Function that is responsible for assig the population to building
JSON EXAMPLE:
(''{"Process":{"IdProcess":"124a9cad-6d21-4037-a362-f41821d35054","MetodFootprint":"True","MetodVolumen":"True","MetodDWellings":"True","MetodResidencialArea":"False","UseFilter":"True","epsg":3035,"BuildingFilter":"False"},"BuildingData":{"Id":1,"SchemaName":"bulding_pop","TableName":"building","IdData":"localId","epsg":25830,"geometry":"geom","useField":"currentUse","useValue":"1_residential","area":"True","area_calculate":"True","area_field":"","volumen":"True","volumen_calculate":"True","volumen_type":"Floor","volumen_field":"numberOfFloorsAboveGround","Dwellings":"True","Dwellings_field":"numberOfDwellings","residential_area":"False","residential_area_field":""},"PopulationData":{"Id":2,"SchemaName":"bulding_pop","TableName":"JRC_POPULATION_2018","Id":"grd_id","epsg":3035,"geometry":"geom","PopulationField":"tot_p_2018"}}''::json);
';


CREATE FUNCTION "POPIMPACT"."_Metadata_CurrentPopulation"(uuid text, field text) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
   
	DECLARE
 	sql_query text;
	results integer;

	BEGIN
   
		 sql_query:= 'SELECT  SUM("'||$2||'")::integer as '||$2||'  FROM results.results_bulding_'||$1;
		 
		EXECUTE consulta_sql INTO results;			 
		return results;
	
			 
 	END;

$_$;


ALTER FUNCTION "POPIMPACT"."_Metadata_CurrentPopulation"(uuid text, field text) OWNER TO postgres;

--
-- TOC entry 987 (class 1255 OID 136034)
-- Name: _Metadata_NBuildingsPop100(text, text); Type: FUNCTION; Schema: POPIMPACT; Owner: postgres
--

CREATE FUNCTION "POPIMPACT"."_Metadata_NBuildingsPop100"(uuid text, field text) RETURNS integer
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


ALTER FUNCTION "POPIMPACT"."_Metadata_NBuildingsPop100"(uuid text, field text) OWNER TO postgres;

--
-- TOC entry 985 (class 1255 OID 136033)
-- Name: _Metadata_NBuildingsWithoutPop(text, text, boolean, text); Type: FUNCTION; Schema: POPIMPACT; Owner: postgres
--

CREATE FUNCTION "POPIMPACT"."_Metadata_NBuildingsWithoutPop"(uuid text, field text, usefilter boolean, usevalue text) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
   
	DECLARE
   sql_query text;
	results integer;

	BEGIN
		IF $3 IS true THEN
		 sql_query:='SELECT COUNT("'||$2||'")::integer FROM results.results_bulding_'||$1||' WHERE (uso='''||$4||''') and "'||$2||'"=0 ';

		 ELSE 
		 sql_query:='SELECT COUNT("'||$2||'")::integer FROM results.results_bulding_'||$1||' WHERE "'||$2||'"=0 ';

		 END IF;
		 
					
		EXECUTE sql_query INTO results;			 
		return results;
			 
			 
 	END;

$_$;


ALTER FUNCTION "POPIMPACT"."_Metadata_NBuildingsWithoutPop"(uuid text, field text, usefilter boolean, usevalue text) OWNER TO postgres;

--
-- TOC entry 988 (class 1255 OID 136035)
-- Name: _Metadata_NBuildingsWithtPop(text, text, boolean, text); Type: FUNCTION; Schema: POPIMPACT; Owner: postgres
--

CREATE FUNCTION "POPIMPACT"."_Metadata_NBuildingsWithtPop"(uuid text, field text, usefilter boolean, usevalue text) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
   
	DECLARE
 	sql_query text;
	results integer;
	
	BEGIN
		IF $3 IS true THEN
		 sql_query:='SELECT COUNT("'||$2||'")::integer  FROM results.results_bulding_'||$1||' WHERE (uso='''||$4||''') and "'||$2||'"<>0 ';

		 ELSE 
		 sql_query:='SELECT COUNT("'||$2||'")::integer  FROM results.results_bulding_'||$1||' WHERE "'||$2||'"<>0 ';

		 END IF;
		 
		EXECUTE sql_query INTO results;			 
		return results;
	
			 
 	END;

$_$;


ALTER FUNCTION "POPIMPACT"."_Metadata_NBuildingsWithtPop"(uuid text, field text, usefilter boolean, usevalue text) OWNER TO postgres;

--
-- TOC entry 989 (class 1255 OID 136043)
-- Name: _NormalizeBuildings(json); Type: FUNCTION; Schema: POPIMPACT; Owner: postgres
--

CREATE FUNCTION "POPIMPACT"."_NormalizeBuildings"(json) RETURNS void
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

 		t timestamp;

	BEGIN
	
	--CONTADOR DE TIEMPO
	  t:= clock_timestamp();
	
	--PARSER INPUT	    
		json_in:=$1::json;
	    EPSGProyect:=(json_entrada->'Process'->>'epsg')::integer; 
        uuid:=REPLACE((json_entrada->'Process'->>'IdProcess'),'-', '_');
		uuid_origen:=(json_entrada->'Process'->>'IdProcess')::uuid;
		
		SchemaBuilding:=(json_entrada->'BuildingData'->>'SchemaName')::text;
		TableBuilding:=(json_entrada->'BuildingData'->>'TableName')::text;
		GeometryBuilding:=(json_entrada->'BuildingData'->>'geometry')::text; 
		EPSGBuilding:=(json_entrada->'BuildingData'->>'epsg')::integer; 
		IdBuilding:=(json_entrada->'BuildingData'->>'IdData')::text;
	 
		area:=(json_entrada->'BuildingData'->>'area')::boolean;
		area_calculate:=(json_entrada->'BuildingData'->>'area_calculate')::boolean;
		area_field:=(json_entrada->'BuildingData'->>'area_field')::text;
	    		
		volumen:=(json_entrada->'BuildingData'->>'volumen')::boolean;
		volumen_calculate:=(json_entrada->'BuildingData'->>'volumen_calculate')::boolean;
		volumen_type:=(json_entrada->'BuildingData'->>'volumen_type')::text;
		volumen_field:=(json_entrada->'BuildingData'->>'volumen_field')::text;	
		
	    dwellings:=(json_entrada->'BuildingData'->>'Dwellings')::boolean; 
		dwellings_field:=(json_entrada->'BuildingData'->>'Dwellings_field')::text;	
		
		sup_residencial:=(json_entrada->'BuildingData'->>'residential_area')::boolean; 
		sup_residencial_field:=(json_entrada->'BuildingData'->>'residential_area_field')::text;		
		
		
		Building_filter:=(json_entrada->'Process'->>'BuildingFilter')::boolean;
		SchemaFilter:=(json_entrada->'FilterData'->>'SchemaName')::text;
		TableFilter:=(json_entrada->'FilterData'->>'TableName')::text;
		GeometryFilter:=(json_entrada->'FilterData'->>'geometry')::text; 
		EPSGFilter:=(json_entrada->'FilterData'->>'epsg')::integer; 
 
		
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
					 "popDwellings", "popResidentialArea", area,elevation, volumen, "numberOfDwellings", "ResidentialArea",geom, geom_pu ';
		 
	 If Building_filter IS TRUE THEN 
	  sql_query:=sql_query||',filter_geom';
	 END IF;
	 
	 sql_query:=sql_query||' FROM (SELECT 	ROW_NUMBER () OVER () as id, '''|| uuid_origen||''' as id_process,
	 edif."'|| IdEdificio||'" as id_buld ,''''::text as id_popu,';
	 

	 IF (FiltrarUso IS True)  THEN	 	 
	
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
			sql_query:=sql_query ||', st_area('|| GeometryBuilding||')  as area';
		  ELSE
			sql_query:=sql_query ||','|| area_field||' as area';
		  END IF;	
	 ELSE
	 	sql_query:=sql_query ||', 0  as  area';		  
	 END IF;

	--VOLUMEN
	 If volumen is true  THEN	 
		sql_query:=sql_query ||', COALESCE(edif."'|| volumen_field||'"::numeric,0) as elevation, 
		COALESCE(st_area('|| GeometryBuilding||')::numeric,0)*';		
			
			IF volumen_type= 'Floor' THEN
				sql_query:=sql_query ||'("'|| volumen_field||'"::integer*3)) as volumen';
			ELSE 
				sql_query:=sql_query ||'"'|| volumen_field||'" as volumen';
			END IF;
		 
	ELSE
	 	sql_query:=sql_query ||', 0  as  elevation, 0  as  volumen';	 
	END IF;

 	--DWELLINGS
		 If dwellings is true  THEN 
				 sql_query:=sql_query ||',edif."'|| dwellings_field||'"  as "numberOfDwellings"';
		ELSE
				 sql_query:=sql_query ||',0  as  "numberOfDwellings"';			
		 END IF; 

 	--  SUP. RESIDENCIAL AREA
		 If sup_residencial is true  THEN 
				 sql_query:=sql_query ||',edif."'|| sup_residencial_field||'"  as  "ResidentialArea"';		
		 ELSE
				 sql_query:=sql_query ||',0 as  "ResidentialArea"';	
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


COMMENT ON FUNCTION "POPIMPACT"."_NormalizeBuildings"(json) IS 'Function that is responsible for normalising the input data to the Inspire building model.
JSON EXAMPLE:
(''{"Process":{"IdProcess":"124a9cad-6d21-4037-a362-f41821d35054","MetodFootprint":"True","MetodVolumen":"True","MetodDWellings":"True","MetodResidencialArea":"False","UseFilter":"True","epsg":3035,"BuildingFilter":"False"},"BuildingData":{"Id":1,"SchemaName":"bulding_pop","TableName":"building","IdData":"localId","epsg":25830,"geometry":"geom","useField":"currentUse","useValue":"1_residential","area":"True","area_calculate":"True","area_field":"","volumen":"True","volumen_calculate":"True","volumen_type":"Floor","volumen_field":"numberOfFloorsAboveGround","Dwellings":"True","Dwellings_field":"numberOfDwellings","residential_area":"False","residential_area_field":""},"PopulationData":{"Id":2,"SchemaName":"bulding_pop","TableName":"JRC_POPULATION_2018","Id":"grd_id","epsg":3035,"geometry":"geom","PopulationField":"tot_p_2018"}}''::json);
';
```

For its use it is necessary to use a JSON with this structure
## *JSON EXAMPLE* 

```
(''{"Process":{"IdProcess":"124a9cad-6d21-4037-a362-f41821d35054","MetodFootprint":"True","MetodVolumen":"True","MetodDWellings":"True","MetodResidencialArea":"False","UseFilter":"True","epsg":3035,"BuildingFilter":"False"},"BuildingData":{"Id":1,"SchemaName":"bulding_pop","TableName":"building","IdData":"localId","epsg":25830,"geometry":"geom","useField":"currentUse","useValue":"1_residential","area":"True","area_calculate":"True","area_field":"","volumen":"True","volumen_calculate":"True","volumen_type":"Floor","volumen_field":"numberOfFloorsAboveGround","Dwellings":"True","Dwellings_field":"numberOfDwellings","residential_area":"False","residential_area_field":""},"PopulationData":{"Id":2,"SchemaName":"bulding_pop","TableName":"JRC_POPULATION_2018","Id":"grd_id","epsg":3035,"geometry":"geom","PopulationField":"tot_p_2018"}}''::json);';```
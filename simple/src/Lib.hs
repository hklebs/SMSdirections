{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}

module Lib where
import Network.URL
import Network.HTTP.Simple
import Control.Monad.IO.Class
import Data.Aeson
import GHC.Generics


someFunc :: IO ()
someFunc = return ()

home :: String


directionKey :: String

               
directionURL :: URL
directionURL = URL {
  url_type = Absolute $ Host {protocol = HTTP True,
                              host = "maps.googleapis.com",
                              port = Nothing},
  url_path = "maps/api/directions/json",
  url_params = []}
  

addOrigin :: String -> URL -> URL
addOrigin orig u = add_param u ("origin", orig)

addDest :: String -> URL -> URL
addDest dest u = add_param u ("destination", dest)

addKey :: String -> URL -> URL
addKey key u = add_param u ("key", key)

addMode :: String -> URL -> URL
addMode m u = add_param u ("mode", m)

stripBold :: String -> String
stripBold "" = ""
stripBold ('<':'/':'b':'>':xs) = stripBold xs
stripBold ('<':'b':'>':xs) = stripBold xs
stripBold (x:xs) = x : stripBold xs


stripTag :: String -> String
stripTag = stripTag' False

stripTag' :: Bool -> String -> String
stripTag' _ "" = ""
stripTag' True ('>':xs) = stripTag' False xs
stripTag' True (_:xs) = stripTag' True xs
stripTag' _ ('<':xs) = stripTag' True xs
stripTag' False (x:xs) = x : stripTag' False xs

getDirections :: (MonadIO m) => URL -> m (Response Directions)
getDirections u = httpJSON $ parseRequest_ $ "GET " ++ exportURL u

showResponse :: (MonadIO m) => m (Response Directions) -> m String
showResponse r = directionResponse <$> getResponseBody <$> r

showDirections :: Directions -> Maybe String
showDirections (Directions _ routes _) 
  | length routes >= 1 = routeLegs (head routes)
  | otherwise = Nothing


directionResponse :: Directions -> String
directionResponse ds = case (showDirections ds) of
  Nothing -> "Malformed query, text :h for help"
  Just u -> u

data Directions = Directions { geocoded_waypoints :: [Waypoint]
                            , routes :: [Route]
                            , status :: String
                            } deriving (Show, Generic)
instance FromJSON Directions
data Waypoint = Waypoint { geocoder_status :: String
                         , place_id :: String
                         , types :: [String]
                         } deriving (Show, Generic)
instance FromJSON Waypoint

routeLegs :: Route -> Maybe String
routeLegs r
  | length (legs r) >= 1 = Just $ showSteps (head (legs r))
  | otherwise = Nothing

data Route = Route { bounds :: Bound
                   , copyrights :: String
                   , legs :: [Leg]
                   , overview_polyline :: Point
                   , summary :: String
                   , warnings :: [String]
                   , waypoint_order :: [String]
                   } deriving (Show, Generic)
instance FromJSON Route

data Bound = Bound { northeast :: Coords
                   , southwest :: Coords
                   } deriving (Show, Generic)
instance FromJSON Bound
data Coords = Coords { lat :: Double
                     , lng :: Double
                     } deriving (Show, Generic)
instance FromJSON Coords

showSteps :: Leg -> String
showSteps l = (concat $ zipWith (++) numbering stepStrings) ++ end
  where stepStrings = showStep <$> steps l 
        numbering = zipWith (++) (show <$> [1..]) (repeat ". ")
        end = "Arrive at " ++ end_address l

data Leg = Leg { distance :: TnV
               , duration :: TnV
               , end_address :: String
               , end_location :: Coords
               , start_location :: Coords
               , steps :: [Step]
               , traffic_speed_entry :: [Int]
               , via_waypoint :: [Int]
               } deriving (Show, Generic)
instance FromJSON Leg

data TnV = TnV { text :: String
               , value :: Int
               } deriving (Show, Generic)

instance FromJSON TnV

showStep :: Step -> String
showStep s = instructions ++ " and go " ++ (text $ distance_step s) ++ "\n"
  where instructions = stripTag $ html_instructions s


data Step = Step { distance_step :: TnV
                 , duration_step :: TnV
                 , end_location_step :: Coords
                 , html_instructions :: String
                 , polyline :: Point
                 , start_location_step :: Coords
                 , travel_mode :: String
                 , maneuver :: Maybe String
                 } deriving Show
            
instance FromJSON Step where
  parseJSON (Object v) = Step <$>
                         v .: "distance" <*>
                         v .: "duration" <*>
                         v .: "end_location" <*>
                         v .: "html_instructions" <*>
                         v .: "polyline" <*>
                         v .: "start_location" <*>
                         v .: "travel_mode" <*>
                         v .:! "maneuver"

data Point = Point { points :: String } deriving (Show, Generic)
instance FromJSON Point

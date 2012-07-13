<?php

namespace GW2CBackend;

class DatabaseAdapter {

    protected $pdo;
    protected $data = array();

    public function connect($host, $port, $database, $user, $pword) {
        
        if($this->pdo instanceof \PDO) return;
        
        try {
            $this->pdo = new \PDO('mysql:host='.$host.';port='.$port.';dbname='.$database, $user, $pword);
        }
        catch(\Exception $e) {
            $this->handleError($e);
        }
    }
    
    public function addModification($json) {
        
        $date = date('Y-m-d H:i:s');
        
        if(!array_key_exists("current-reference", $this->data)) {
            $this->retrieveCurrentReference();
        }

        $idReference = $this->data["current-reference"]["id"];
        
        $json = addslashes($json);

        $q = "INSERT INTO modification_list (date_added, value, id_reference_at_submission) 
                         VALUES ('".$date."', '".$json."', '".$idReference."')";

        $r = $this->pdo->exec($q);
    }
    
    public function addReference($reference, $maxMarkerID, $idModification) {
        
        $date = date('Y-m-d H:i:s');
        $jsonReference = json_encode($reference);
        
        if(!array_key_exists("current-reference", $this->data)) {
            $this->retrieveCurrentReference();
        }

        $q = "INSERT INTO reference_list (value, date_added, id_merged_modification, max_marker_id) 
                         VALUES ('".$jsonReference."', '".$date."', '".$idModification."', '".$maxMarkerID."')";

        $this->pdo->exec($q);
    }

    public function retrieveAll() {
        $this->retrieveOptions();
        //$this->retrieveResources();
        $this->retrieveAreasList();
        $this->retrieveCurrentReference();
        $this->retrieveFirstModification();
        //$this->retrieveReferenceAtSubmission($this->data['first-modification']['reference-at-submission']);
    }
    
    public function retrieveModificationList() {
        $result = $this->pdo->query("SELECT * FROM modification_list WHERE is_merged = 0");
        $result->setFetchMode(\PDO::FETCH_ASSOC);
        
        return $result->fetchAll();
    }
    
    public function retrieveReferenceAtSubmission($referenceID) {
        $result = $this->pdo->query("SELECT * FROM reference_list WHERE id = ".$referenceID."");
        
        $result->setFetchMode(\PDO::FETCH_ASSOC);
        
        $this->data["reference-at-submission"] = $result->fetch();
    }
    
    public function retrieveCurrentReference() {
        
        $result = $this->pdo->query("SELECT * FROM reference_list ORDER BY date_added DESC LIMIT 0,1");
        
        $result->setFetchMode(\PDO::FETCH_ASSOC);
        
        $this->data["current-reference"] = $result->fetch();
    }

    public function retrieveOptions() {
        $result = $this->pdo->query("SELECT * FROM options");
        $result->setFetchMode(\PDO::FETCH_ASSOC);

        foreach($result->fetchAll() as $row) {
            
            $this->data["options"][$row["id"]] = $row["value"];
        }
    }
    
    public function getMarkerGroups() {
        $result = $this->pdo->query("SELECT * FROM marker_group");
        $result->setFetchMode(\PDO::FETCH_ASSOC);
        
        $r = array();
        foreach($result->fetchAll() as $res) {

            $res['translated_data'] = $this->getTranslatedData($res['id_translated_data']);;
            
            $r[$res['slug']] = $res;
        }
        
        $this->data["marker.groups"] = $r;
        
        return $r;
    }
    
    public function getTranslatedData($id) {
        
        if($id == null) {
            $tData = new TranslatedData();
        }
        else {
            $q = "SELECT * FROM translated_data WHERE id = ".$id;

            $data = $this->pdo->query($q);
            $data->setFetchMode(\PDO::FETCH_ASSOC);
            $tData = array();
            foreach($data->fetchAll() as $d) {
                $tData[$d['lang']][$d['key']] = $d['value'];
            }
        
            $tData = new TranslatedData($tData);
        }

        return $tData;
    }

    public function getMarkerTypes() {
        $result = $this->pdo->query("SELECT * FROM marker_type");
        $result->setFetchMode(\PDO::FETCH_ASSOC);

        $r = array();
        foreach($result->fetchAll() as $res) {

            $res['translated_data'] = $this->getTranslatedData($res['id_translated_data']);
            $r[$res['id']] = $res;
        }

        $this->data["marker.types"] = $r;
        
        return $r;
    }
    
    public function getMarkersStructure() {
        $markerGroups = $this->getMarkerGroups();
        $markerTypes = $this->getMarkerTypes();

        foreach($markerTypes as $markerType) {
            $markerGroups[$markerType['slug_marker_group']]['markerTypes'][$markerType['id']] = $markerType;
        }

        return $markerGroups;
    }

    public function retrieveAreasList() {
        $result = $this->pdo->query("SELECT * FROM areas_list");
        $result->setFetchMode(\PDO::FETCH_ASSOC);
        
        foreach($result->fetchAll() as $row) {
            $this->data["areas-list"][$row["id"]] = $row;
        }
        
        return $this->data["areas-list"];
    }
    
    public function retrieveModification($idModification) {
        $result = $this->pdo->query("SELECT * FROM modification_list WHERE id = ".$idModification);
        $result->setFetchMode(\PDO::FETCH_ASSOC);

        return $result->fetch();
    }
    
    public function retrieveFirstModification() {
        $result = $this->pdo->query("SELECT * FROM modification_list WHERE is_merged = 0 ORDER BY date_added LIMIT 0,1");
        $result->setFetchMode(\PDO::FETCH_ASSOC);
        
        $this->data["first-modification"] = $result->fetch();
    }
    
    public function getData($index = null) {
        
        if($index == null) {
            return $this->data;
        }
        else {
            return $this->data[$index];
        }
    }

    public function handleError(\Exception $e) {
        var_dump($e);
    }

}